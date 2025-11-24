// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionAccounts {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when trying to remove an account that doesn't exist
    error AccountNotFound();

    // ============================================
    // FUNCTIONS - Account Status
    // ============================================

    /// @notice Get all accounts that have joined
    /// @return Array of account addresses
    function accounts() external view returns (address[] memory);

    /// @notice Get the number of accounts
    /// @return Count of accounts
    function accountsCount() external view returns (uint256);

    /// @notice Get account at a specific index
    /// @param index The index in the accounts array
    /// @return The account address
    function accountAtIndex(uint256 index) external view returns (address);
}
