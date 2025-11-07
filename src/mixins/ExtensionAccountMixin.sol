// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";

/// @title ExtensionAccountMixin
/// @notice Mixin for managing extension accounts
/// @dev Provides account tracking and management functionality
abstract contract ExtensionAccountMixin is ExtensionCoreMixin {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Array of accounts participating in this extension
    address[] internal _accounts;

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get all accounts
    function accounts() external view returns (address[] memory) {
        return _accounts;
    }

    /// @notice Get the count of accounts
    function accountsCount() external view returns (uint256) {
        return _accounts.length;
    }

    /// @notice Get account at specific index
    /// @param index The index
    function accountAtIndex(uint256 index) external view returns (address) {
        return _accounts[index];
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Add an account to the internal accounts array and center registry
    /// @param account The account address to add
    function _addAccount(address account) internal {
        _accounts.push(account);
        ILOVE20ExtensionCenter(center()).addAccount(
            tokenAddress,
            actionId,
            account
        );
    }

    /// @dev Remove an account from the internal accounts array and center registry
    /// @param account The account address to remove
    function _removeAccount(address account) internal {
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (_accounts[i] == account) {
                _accounts[i] = _accounts[_accounts.length - 1];
                _accounts.pop();
                break;
            }
        }
        ILOVE20ExtensionCenter(center()).removeAccount(
            tokenAddress,
            actionId,
            account
        );
    }
}

