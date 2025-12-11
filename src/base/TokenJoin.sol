// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {VerificationInfo} from "./VerificationInfo.sol";
import {ITokenJoin} from "../interface/base/ITokenJoin.sol";
import {IExit} from "../interface/base/IExit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title TokenJoin
/// @notice Base contract providing token-based join/exit functionality
/// @dev Implements ITokenJoin interface with ERC20 token participation and block-based waiting period
abstract contract TokenJoin is
    ExtensionCore,
    VerificationInfo,
    ReentrancyGuard,
    ITokenJoin
{
    // ============================================
    // STATE VARIABLES - IMMUTABLE CONFIG
    // ============================================

    /// @notice The token that can be joined
    address public immutable joinTokenAddress;

    /// @notice Number of blocks to wait before exit after joining
    uint256 public immutable waitingBlocks;

    // ============================================
    // STATE VARIABLES - JOIN STATE
    // ============================================

    /// @notice Total amount currently joined
    uint256 public totalJoinedAmount;

    /// @dev Mapping from account to their join information
    mapping(address => JoinInfo) internal _joinInfo;

    /// @dev ERC20 interface for the join token
    IERC20 internal _joinToken;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the token join extension
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before exit
    constructor(address joinTokenAddress_, uint256 waitingBlocks_) {
        if (joinTokenAddress_ == address(0)) {
            revert ITokenJoin.InvalidJoinTokenAddress();
        }
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    // ============================================
    // ITOKENJOIN INTERFACE
    // ============================================

    /// @inheritdoc ITokenJoin
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual nonReentrant {
        // Auto-initialize if not initialized
        _autoInitialize();

        if (amount == 0) {
            revert JoinAmountZero();
        }

        JoinInfo storage info = _joinInfo[msg.sender];
        bool isFirstJoin = info.joinedBlock == 0;

        // Update state
        if (isFirstJoin) {
            info.joinedRound = _join.currentRound();
        }
        info.amount += amount;
        info.joinedBlock = block.number;
        totalJoinedAmount += amount;

        // Add to center accounts only on first join
        if (isFirstJoin) {
            _center.addAccount(tokenAddress, actionId, msg.sender);
        }

        // Transfer tokens from user
        _joinToken.transferFrom(msg.sender, address(this), amount);

        // Update verification info if provided
        updateVerificationInfo(verificationInfos);

        emit Join(
            tokenAddress,
            _join.currentRound(),
            actionId,
            msg.sender,
            amount,
            block.number
        );
    }

    /// @inheritdoc IExit
    function exit() public virtual nonReentrant {
        JoinInfo storage info = _joinInfo[msg.sender];
        if (info.joinedBlock == 0) {
            revert NoJoinedAmount();
        }
        if (block.number < info.joinedBlock + waitingBlocks) {
            revert NotEnoughWaitingBlocks();
        }

        uint256 amount = info.amount;

        // Clear join info
        info.joinedRound = 0;
        info.amount = 0;
        info.joinedBlock = 0;
        totalJoinedAmount -= amount;

        // Remove from center accounts
        _center.removeAccount(tokenAddress, actionId, msg.sender);

        // Transfer tokens back to user
        _joinToken.transfer(msg.sender, amount);

        emit Exit(
            tokenAddress,
            _join.currentRound(),
            actionId,
            msg.sender,
            amount
        );
    }

    /// @inheritdoc ITokenJoin
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
        JoinInfo storage info = _joinInfo[account];
        return (
            info.joinedRound,
            info.amount,
            info.joinedBlock,
            info.joinedBlock == 0 ? 0 : info.joinedBlock + waitingBlocks
        );
    }
}
