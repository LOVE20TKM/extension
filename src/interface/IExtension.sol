// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtension {
    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when a user claims a reward
    event ClaimReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when trying to initialize an already initialized extension
    error AlreadyInitialized();

    /// @notice Thrown when an invalid token address is provided
    error InvalidTokenAddress();

    /// @notice Thrown when no matching action ID is found during auto-initialization
    error ActionIdNotFound();

    /// @notice Thrown when multiple matching action IDs are found during auto-initialization
    error MultipleActionIdsFound();

    /// @notice Thrown when a reward has already been claimed for a round
    error AlreadyClaimed();

    /// @notice Thrown when a round is not finished
    error RoundNotFinished();

    // ============================================
    // FUNCTIONS - Core
    // ============================================

    /// @notice Get the center contract address
    /// @return The center address
    function center() external view returns (address);

    /// @notice Initialize action by joining through LOVE20Join
    /// @dev Called when extension needs to auto-initialize by scanning voted actions
    function initializeAction() external;

    /// @notice Get the factory contract address
    /// @return The factory address
    function factory() external view returns (address);

    /// @notice Get the token address for this extension
    /// @return The token address
    function tokenAddress() external view returns (address);

    /// @notice Get the action ID for this extension
    /// @return The action ID
    function actionId() external view returns (uint256);

    /// @notice Check if the extension has been initialized
    /// @return True if initialized, false otherwise
    function initialized() external view returns (bool);

    // ============================================
    // FUNCTIONS - Joined Value Status
    // ============================================

    /// @notice Check if joined value is calculated
    /// @return True if joined value is calculated
    function isJoinedValueCalculated() external view returns (bool);

    /// @notice Get total joined value
    /// @return Total joined value
    function joinedValue() external view returns (uint256);

    /// @notice Get joined value for a specific account
    /// @param account The account address
    /// @return Joined value for the account
    function joinedValueByAccount(
        address account
    ) external view returns (uint256);

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

    /// @notice Get total reward for a specific round
    /// @param round The round number
    /// @return Total reward amount for the round
    function reward(uint256 round) external view returns (uint256);
}
