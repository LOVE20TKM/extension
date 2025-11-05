// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionAutoScore} from "./ILOVE20ExtensionAutoScore.sol";

/// @title ILOVE20ExtensionAutoScoreStake
/// @notice Interface for auto-score-based stake LOVE20 extensions with waiting period mechanism
/// @dev Provides common staking functionality with unstake waiting period for AutoScore extensions
interface ILOVE20ExtensionAutoScoreStake is ILOVE20ExtensionAutoScore {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Error thrown when trying to stake while an unstake request is pending
    error UnstakeRequested();

    /// @notice Error thrown when trying to stake zero amount
    error StakeAmountZero();

    /// @notice Error thrown when trying to unstake with no staked amount
    error NoStakedAmount();

    /// @notice Error thrown when trying to withdraw without requesting unstake first
    error UnstakeNotRequested();

    /// @notice Error thrown when trying to withdraw before waiting period ends
    error NotEnoughWaitingPhases();

    /// @notice Error thrown when user's governance votes are insufficient to stake
    error InsufficientGovVotes();

    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when a user stakes tokens
    /// @param account The account that staked
    /// @param amount The amount staked
    event Stake(address indexed account, uint256 amount);

    /// @notice Emitted when a user requests to unstake tokens
    /// @param account The account that unstaked
    /// @param amount The amount unstaked
    event Unstake(address indexed account, uint256 amount);

    /// @notice Emitted when a user withdraws tokens after waiting period
    /// @param account The account that withdrew
    /// @param amount The amount withdrawn
    event Withdraw(address indexed account, uint256 amount);

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Stake information for an account
    /// @param amount The staked amount
    /// @param requestedUnstakeRound The round when unstake was requested (0 if no request)
    struct StakeInfo {
        uint256 amount;
        uint256 requestedUnstakeRound;
    }

    // ============================================
    // CONFIGURATION GETTERS
    // ============================================

    /// @notice Get the token address that can be staked
    /// @return The stake token address
    function stakeTokenAddress() external view returns (address);

    /// @notice Get the number of phases to wait before withdrawal after unstaking
    /// @return The number of waiting phases
    function waitingPhases() external view returns (uint256);

    /// @notice Get the minimum governance votes required to stake
    /// @return The minimum governance votes
    function minGovVotes() external view returns (uint256);

    // ============================================
    // USER OPERATIONS
    // ============================================

    /// @notice Stake tokens to participate in the extension
    /// @param amount The amount to stake
    function stake(uint256 amount) external;

    /// @notice Request to unstake all staked tokens
    /// @dev Starts the waiting period before withdrawal
    function unstake() external;

    /// @notice Withdraw tokens after the waiting period
    /// @dev Can only be called after waiting period ends
    function withdraw() external;

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get stake information for an account
    /// @param account The account to query
    /// @return amount The staked amount
    /// @return requestedUnstakeRound The round when unstake was requested
    function stakeInfo(
        address account
    ) external view returns (uint256 amount, uint256 requestedUnstakeRound);

    /// @notice Get all accounts that have requested unstaking
    /// @return Array of unstaker addresses
    function unstakers() external view returns (address[] memory);

    /// @notice Get the number of unstakers
    /// @return The count of unstakers
    function unstakersCount() external view returns (uint256);

    /// @notice Get an unstaker at a specific index
    /// @param index The index to query
    /// @return The unstaker address
    function unstakersAtIndex(uint256 index) external view returns (address);

    /// @notice Get the total amount currently staked
    /// @return The total staked amount
    function totalStakedAmount() external view returns (uint256);

    /// @notice Get the total amount that has been unstaked but not withdrawn
    /// @return The total unstaked amount
    function totalUnstakedAmount() external view returns (uint256);
}
