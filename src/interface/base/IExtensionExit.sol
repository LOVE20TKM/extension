// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/// @title IExtensionExit
/// @notice Interface for extension exit functionality
/// @dev Defines the exit operation that allows participants to leave the extension
interface IExtensionExit {
    /// @notice Exit from the extension
    /// @dev Implementations should handle cleanup and return of resources to msg.sender
    /// Specific exit events should be defined in child interfaces based on their needs
    function exit() external;
}
