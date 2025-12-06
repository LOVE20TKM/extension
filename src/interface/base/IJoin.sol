// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionExit} from "./IExtensionExit.sol";

/// @title IJoin
/// @notice Interface for token-free join functionality
/// @dev Defines join/withdraw operations without token requirements and block-delayed withdrawal
interface IJoin is IExtensionExit {
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
    /// @param round The current round
    /// @param actionId The action ID this extension is associated with
    /// @param account The account that joined
    event Join(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account
    );

    /// @notice Emitted when an account exits
    /// @param tokenAddress The token address this extension is associated with
    /// @param round The current round
    /// @param actionId The action ID this extension is associated with
    /// @param account The account that exited
    event Exit(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account
    );

    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================

    /// @notice Join to participate in the extension
    /// @param verificationInfos Optional verification information array
    function join(string[] memory verificationInfos) external;
}
