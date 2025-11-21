// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/// @title ITokenJoin
/// @notice Interface for token-based join functionality
/// @dev Defines join/withdraw operations with ERC20 token-based participation and block-delayed withdrawal
interface ITokenJoin {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when trying to join with zero amount
    error JoinAmountZero();

    /// @notice Thrown when account has no joined amount
    error NoJoinedAmount();

    /// @notice Thrown when trying to exit before waiting period ends
    error NotEnoughWaitingBlocks();

    /// @notice Thrown when account has already joined
    error AlreadyJoined();

    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when an account joins
    /// @param tokenAddress The token address this extension is associated with
    /// @param account The account that joined
    /// @param actionId The action ID this extension is associated with
    /// @param amount The amount of tokens joined
    /// @param joinedBlock The block number when the join occurred
    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount,
        uint256 joinedBlock
    );

    /// @notice Emitted when an account exits
    /// @param tokenAddress The token address this extension is associated with
    /// @param account The account that exited
    /// @param actionId The action ID this extension is associated with
    /// @param amount The amount of tokens withdrawn
    event Exit(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Information about an account's join
    /// @param amount The amount of tokens joined
    /// @param joinedBlock The block number when the join occurred
    struct JoinInfo {
        uint256 amount;
        uint256 joinedBlock;
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get the token address that can be joined
    /// @return The join token address
    function joinTokenAddress() external view returns (address);

    /// @notice Get the number of blocks to wait before exit
    /// @return The waiting period in blocks
    function waitingBlocks() external view returns (uint256);

    /// @notice Get the total amount of tokens joined by all accounts
    /// @return The total joined amount
    function totalJoinedAmount() external view returns (uint256);

    /// @notice Get join information for a specific account
    /// @param account The account address to query
    /// @return amount The amount of tokens joined
    /// @return joinedBlock The block number when the join occurred
    /// @return exitableBlock The block number when exit becomes available
    function joinInfo(
        address account
    )
        external
        view
        returns (
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        );

    /// @notice Check if an account can exit
    /// @param account The account address to check
    /// @return True if the account can exit
    function canExit(address account) external view returns (bool);

    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================

    /// @notice Join with tokens to participate in the extension
    /// @param amount The amount of tokens to join with
    /// @param verificationInfos Optional verification information array
    function join(uint256 amount, string[] memory verificationInfos) external;

    /// @notice Exit and withdraw joined tokens after the waiting period
    function exit() external;
}
