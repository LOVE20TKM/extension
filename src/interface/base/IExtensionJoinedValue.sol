// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionJoinedValue {
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
}

