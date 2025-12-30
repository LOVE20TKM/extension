// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtension} from "./IExtension.sol";

/// @title IExtensionJoin
/// @notice Interface for base join extensions
/// @dev Combines Extension with token-free join/withdraw mechanisms
interface IExtensionJoin is IExtension {
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
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get join information for a specific account
    /// @param account The account address to query
    /// @return joinedRound The round when the account joined, 0 if not joined
    function joinInfo(
        address account
    ) external view returns (uint256 joinedRound);

    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================

    /// @notice Join to participate in the extension
    /// @param verificationInfos Optional verification information array
    function join(string[] memory verificationInfos) external;

    /// @notice Exit from the extension
    /// @dev Implementations should handle cleanup and return of resources to msg.sender
    function exit() external;
}

