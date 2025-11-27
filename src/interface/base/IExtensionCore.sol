// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionCore {
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

    // ============================================
    // FUNCTIONS - Core
    // ============================================

    /// @notice Get the center contract address
    /// @return The center address
    function center() external view returns (address);

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
}
