// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/// @title IJoin
/// @notice Interface for token-free join functionality
/// @dev Defines join/withdraw operations without token requirements and block-delayed withdrawal
interface IJoin {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when account has not joined
    error NotJoined();

    /// @notice Thrown when account has already joined
    error AlreadyJoined();

    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when an account joins
    /// @param tokenAddress The token address this extension is associated with
    /// @param account The account that joined
    /// @param actionId The action ID this extension is associated with
    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId
    );

    /// @notice Emitted when an account withdraws
    /// @param tokenAddress The token address this extension is associated with
    /// @param account The account that withdrew
    /// @param actionId The action ID this extension is associated with
    event Withdraw(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId
    );

    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================

    /// @notice Join to participate in the extension
    /// @param verificationInfos Optional verification information array
    function join(string[] memory verificationInfos) external;

    /// @notice Withdraw from the extension
    function withdraw() external;
}
