// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ITokenJoin} from "./interface/ITokenJoin.sol";
import {ExtensionBaseReward} from "./ExtensionBaseReward.sol";
import {ExtensionBase} from "./ExtensionBase.sol";
import {RoundHistoryUint256} from "./lib/RoundHistoryUint256.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ExtensionBaseRewardTokenJoin is
    ExtensionBaseReward,
    ITokenJoin
{
    using SafeERC20 for IERC20;
    using RoundHistoryUint256 for RoundHistoryUint256.History;
    address public immutable JOIN_TOKEN_ADDRESS;

    uint256 public immutable WAITING_BLOCKS;

    IERC20 internal immutable _joinToken;

    // account => joinedRound
    mapping(address => uint256) internal _joinedRoundByAccount;

    // account => joinedBlock
    mapping(address => uint256) internal _lastJoinedBlockByAccount;

    // account => amount
    mapping(address => RoundHistoryUint256.History)
        internal _joinedAmountByAccountHistory;

    RoundHistoryUint256.History internal _joinedAmountHistory;

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
        bool isFirstJoin = _lastJoinedBlockByAccount[msg.sender] == 0;

        _joinedAmountByAccountHistory[msg.sender].increase(
            currentRound,
            amount
        );

        _joinedAmountHistory.increase(currentRound, amount);

        _lastJoinedBlockByAccount[msg.sender] = block.number;

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
        uint256 joinedBlock = _lastJoinedBlockByAccount[msg.sender];
        if (joinedBlock == 0) {
            revert NotJoined();
        }
        uint256 exitableBlock = joinedBlock + WAITING_BLOCKS;
        if (block.number < exitableBlock) {
            revert NotEnoughWaitingBlocks(block.number, exitableBlock);
        }

        uint256 amount = _joinedAmountByAccountHistory[msg.sender]
            .latestValue();
        uint256 currentRound = _join.currentRound();

        _joinedAmountByAccountHistory[msg.sender].record(currentRound, 0);
        _joinedAmountHistory.decrease(currentRound, amount);
        delete _joinedRoundByAccount[msg.sender];
        delete _lastJoinedBlockByAccount[msg.sender];

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
            uint256 lastJoinedBlock,
            uint256 exitableBlock
        )
    {
        lastJoinedBlock = _lastJoinedBlockByAccount[account];
        return (
            _joinedRoundByAccount[account],
            _joinedAmountByAccountHistory[account].latestValue(),
            lastJoinedBlock,
            lastJoinedBlock == 0 ? 0 : lastJoinedBlock + WAITING_BLOCKS
        );
    }

    function joinedAmountTokenAddress()
        external
        view
        virtual
        override(ExtensionBase)
        returns (address)
    {
        return JOIN_TOKEN_ADDRESS;
    }

    function joinedAmount()
        external
        view
        virtual
        override(ExtensionBase)
        returns (uint256)
    {
        return _joinedAmountHistory.latestValue();
    }

    function joinedAmountByAccount(
        address account
    ) external view virtual override(ExtensionBase) returns (uint256) {
        return _joinedAmountByAccountHistory[account].latestValue();
    }

    function joinedAmountByRound(uint256 round) public view returns (uint256) {
        return _joinedAmountHistory.value(round);
    }

    function joinedAmountByAccountByRound(
        address account,
        uint256 round
    ) public view returns (uint256) {
        return _joinedAmountByAccountHistory[account].value(round);
    }
}
