// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionBase} from "./ExtensionBase.sol";
import {IExtensionTokenJoin} from "./interface/IExtensionTokenJoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {RoundHistoryUint256} from "./lib/RoundHistoryUint256.sol";

using SafeERC20 for IERC20;
using RoundHistoryUint256 for RoundHistoryUint256.History;

abstract contract ExtensionBaseTokenJoin is ExtensionBase, IExtensionTokenJoin {
    address public immutable joinTokenAddress;

    uint256 public immutable waitingBlocks;

    // account => joinedRound
    mapping(address => uint256) internal _joinedRoundByAccount;

    // account => joinedBlock
    mapping(address => uint256) internal _joinedBlockByAccount;

    // account => amount
    mapping(address => RoundHistoryUint256.History)
        internal _amountHistoryByAccount;

    RoundHistoryUint256.History internal _totalJoinedAmountHistory;

    IERC20 internal _joinToken;

    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) ExtensionBase(factory_, tokenAddress_) {
        if (joinTokenAddress_ == address(0)) {
            revert InvalidJoinTokenAddress();
        }
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual nonReentrant {
        _autoInitialize();

        if (amount == 0) {
            revert JoinAmountZero();
        }

        uint256 currentRound = _join.currentRound();
        bool isFirstJoin = _joinedBlockByAccount[msg.sender] == 0;

        uint256 prevAmount = _amountHistoryByAccount[msg.sender].latestValue();
        uint256 newAmount = prevAmount + amount;
        _amountHistoryByAccount[msg.sender].record(currentRound, newAmount);

        uint256 prevTotal = _totalJoinedAmountHistory.latestValue();
        _totalJoinedAmountHistory.record(currentRound, prevTotal + amount);

        _joinedBlockByAccount[msg.sender] = block.number;

        if (isFirstJoin) {
            _joinedRoundByAccount[msg.sender] = currentRound;
            _center.addAccount(
                tokenAddress,
                actionId,
                msg.sender,
                verificationInfos
            );
        } else if (verificationInfos.length > 0) {
            _center.updateVerificationInfo(
                tokenAddress,
                actionId,
                msg.sender,
                verificationInfos
            );
        }

        _joinToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Join(
            tokenAddress,
            currentRound,
            actionId,
            msg.sender,
            amount,
            block.number
        );
    }

    function exit() public virtual nonReentrant {
        uint256 joinedBlock = _joinedBlockByAccount[msg.sender];
        if (joinedBlock == 0) {
            revert NoJoinedAmount();
        }
        if (block.number < joinedBlock + waitingBlocks) {
            revert NotEnoughWaitingBlocks();
        }

        uint256 amount = _amountHistoryByAccount[msg.sender].latestValue();
        uint256 currentRound = _join.currentRound();

        _amountHistoryByAccount[msg.sender].record(currentRound, 0);
        _totalJoinedAmountHistory.record(
            currentRound,
            _totalJoinedAmountHistory.latestValue() - amount
        );
        delete _joinedRoundByAccount[msg.sender];
        delete _joinedBlockByAccount[msg.sender];

        _center.removeAccount(tokenAddress, actionId, msg.sender);

        _joinToken.safeTransfer(msg.sender, amount);

        emit Exit(tokenAddress, currentRound, actionId, msg.sender, amount);
    }

    function joinInfo(
        address account
    )
        external
        view
        virtual
        returns (
            uint256 joinedRound,
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        )
    {
        joinedBlock = _joinedBlockByAccount[account];
        return (
            _joinedRoundByAccount[account],
            _amountHistoryByAccount[account].latestValue(),
            joinedBlock,
            joinedBlock == 0 ? 0 : joinedBlock + waitingBlocks
        );
    }

    function totalJoinedAmount() public view returns (uint256) {
        return _totalJoinedAmountHistory.latestValue();
    }

    function totalJoinedAmountByRound(
        uint256 round
    ) public view returns (uint256) {
        return _totalJoinedAmountHistory.value(round);
    }

    function amountByAccountByRound(
        address account,
        uint256 round
    ) public view returns (uint256) {
        return _amountHistoryByAccount[account].value(round);
    }
}
