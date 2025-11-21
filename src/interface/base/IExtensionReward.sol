// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionReward {
    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when a user claims a reward
    event ClaimReward(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 round,
        uint256 reward
    );

    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when a reward has already been claimed for a round
    error AlreadyClaimed();

    /// @notice Thrown when a round is not finished
    error RoundNotFinished();

    // ============================================
    // FUNCTIONS - Reward
    // ============================================

    /// @notice Get reward information for an account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return reward The reward amount
    /// @return isMinted Whether the reward has been minted/claimed
    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted);

    /// @notice Claim reward for a specific round
    /// @param round The round number
    /// @return reward The claimed reward amount
    function claimReward(uint256 round) external returns (uint256 reward);
}

