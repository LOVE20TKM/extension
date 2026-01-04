// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionBaseReward} from "./ExtensionBaseReward.sol";
import {ITokenJoin} from "./interface/ITokenJoin.sol";
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

abstract contract ExtensionBaseRewardTokenJoin is
    ExtensionBaseReward,
    ITokenJoin
{
    address public immutable JOIN_TOKEN_ADDRESS;

    uint256 public immutable WAITING_BLOCKS;

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
    ) ExtensionBaseReward(factory_, tokenAddress_) {
        if (joinTokenAddress_ == address(0)) {
            revert InvalidJoinTokenAddress();
        }
        JOIN_TOKEN_ADDRESS = joinTokenAddress_;
        WAITING_BLOCKS = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual nonReentrant {
        initializeIfNeeded();

        if (amount == 0) {
            revert JoinAmountZero();
        }

        uint256 currentRound = _join.currentRound();
        bool isFirstJoin = _joinedBlockByAccount[msg.sender] == 0;

        _amountHistoryByAccount[msg.sender].record(
            currentRound,
            _amountHistoryByAccount[msg.sender].latestValue() + amount
        );

        _totalJoinedAmountHistory.record(
            currentRound,
            _totalJoinedAmountHistory.latestValue() + amount
        );

        _joinedBlockByAccount[msg.sender] = block.number;

        if (isFirstJoin) {
            _joinedRoundByAccount[msg.sender] = currentRound;
            _center.addAccount(
                TOKEN_ADDRESS,
                actionId,
                msg.sender,
                verificationInfos
            );
        } else if (verificationInfos.length > 0) {
            _center.updateVerificationInfo(
                TOKEN_ADDRESS,
                actionId,
                msg.sender,
                verificationInfos
            );
        }

        _joinToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Join({
            tokenAddress: TOKEN_ADDRESS,
            round: currentRound,
            actionId: actionId,
            account: msg.sender,
            amount: amount
        });
    }

    function exit() public virtual nonReentrant {
        uint256 joinedBlock = _joinedBlockByAccount[msg.sender];
        if (joinedBlock == 0) {
            revert NotJoined();
        }
        if (block.number < joinedBlock + WAITING_BLOCKS) {
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

        _center.removeAccount(TOKEN_ADDRESS, actionId, msg.sender);

        _joinToken.safeTransfer(msg.sender, amount);

        emit Exit({
            tokenAddress: TOKEN_ADDRESS,
            round: currentRound,
            actionId: actionId,
            account: msg.sender,
            amount: amount
        });
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
            joinedBlock == 0 ? 0 : joinedBlock + WAITING_BLOCKS
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

    function amountByAccount(address account) public view returns (uint256) {
        return _amountHistoryByAccount[account].latestValue();
    }

    function amountByAccountByRound(
        address account,
        uint256 round
    ) public view returns (uint256) {
        return _amountHistoryByAccount[account].value(round);
    }
}
