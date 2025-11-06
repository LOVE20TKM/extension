// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionAutoScore} from "./ILOVE20ExtensionAutoScore.sol";

/// @title ILOVE20ExtensionAutoScoreJoin
/// @notice Interface for auto-score-based join LOVE20 extensions with block-based waiting period
/// @dev Provides common join functionality with block-based waiting period for AutoScore extensions
interface ILOVE20ExtensionAutoScoreJoin is ILOVE20ExtensionAutoScore {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Error thrown when trying to join with zero amount
    error JoinAmountZero();

    /// @notice Error thrown when trying to withdraw with no joined amount
    error NoJoinedAmount();

    /// @notice Error thrown when trying to withdraw before waiting period ends
    error NotEnoughWaitingBlocks();

    /// @notice Error thrown when user's governance votes are insufficient to join
    error InsufficientGovVotes();

    /// @notice Error thrown when trying to join again while already joined
    error AlreadyJoined();

    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when a user joins with tokens
    /// @param account The account that joined
    /// @param amount The amount joined
    /// @param joinedBlock The block number when joined
    event Join(address indexed account, uint256 amount, uint256 joinedBlock);

    /// @notice Emitted when a user withdraws tokens after waiting period
    /// @param account The account that withdrew
    /// @param amount The amount withdrawn
    event Withdraw(address indexed account, uint256 amount);

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Join information for an account
    /// @param amount The joined amount
    /// @param joinedBlock The block number when join was made (0 if not joined)
    struct JoinInfo {
        uint256 amount;
        uint256 joinedBlock;
    }

    // ============================================
    // CONFIGURATION GETTERS
    // ============================================

    /// @notice Get the token address that can be joined
    /// @return The join token address
    function joinTokenAddress() external view returns (address);

    /// @notice Get the number of blocks to wait before withdrawal after joining
    /// @return The number of waiting blocks
    function waitingBlocks() external view returns (uint256);

    /// @notice Get the minimum governance votes required to join
    /// @return The minimum governance votes
    function minGovVotes() external view returns (uint256);

    // ============================================
    // USER OPERATIONS
    // ============================================

    /// @notice Join with tokens to participate in the extension
    /// @param amount The amount to join with
    function join(uint256 amount) external;

    /// @notice Withdraw tokens after the waiting period
    /// @dev Can only be called after waiting blocks have passed
    function withdraw() external;

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get join information for an account
    /// @param account The account to query
    /// @return amount The joined amount
    /// @return joinedBlock The block when join was made
    function joinInfo(
        address account
    ) external view returns (uint256 amount, uint256 joinedBlock);

    /// @notice Get the total amount currently joined
    /// @return The total joined amount
    function totalJoinedAmount() external view returns (uint256);

    /// @notice Check if an account can withdraw
    /// @param account The account to check
    /// @return Whether the account can withdraw now
    function canWithdraw(address account) external view returns (bool);

    /// @notice Get the block number when an account can withdraw
    /// @param account The account to check
    /// @return The block number when withdrawal is allowed (0 if not joined)
    function withdrawableBlock(address account) external view returns (uint256);
}
