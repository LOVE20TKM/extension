// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionCore {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when a function is called by non-center address
    error OnlyCenterCanCall();

    /// @notice Thrown when trying to initialize an already initialized extension
    error AlreadyInitialized();

    /// @notice Thrown when an invalid token address is provided
    error InvalidTokenAddress();

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

    /// @notice Initialize the extension (can only be called once by Center)
    /// @param tokenAddress The token address to associate with this extension
    /// @param actionId The action ID to associate with this extension
    function initialize(address tokenAddress, uint256 actionId) external;
}
