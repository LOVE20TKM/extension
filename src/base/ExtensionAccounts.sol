// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {IExtensionAccounts} from "../interface/base/IExtensionAccounts.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";

/// @title ExtensionAccounts
/// @notice Base contract providing account management functionality
/// @dev Implements IExtensionAccounts interface with internal account tracking
abstract contract ExtensionAccounts is ExtensionCore, IExtensionAccounts {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Array of accounts participating in this extension
    address[] internal _accounts;

    // ============================================
    // IEXTENSIONACCOUNTS INTERFACE
    // ============================================

    /// @inheritdoc IExtensionAccounts
    function accounts() external view virtual returns (address[] memory) {
        return _accounts;
    }

    /// @inheritdoc IExtensionAccounts
    function accountsCount() external view virtual returns (uint256) {
        return _accounts.length;
    }

    /// @inheritdoc IExtensionAccounts
    function accountAtIndex(
        uint256 index
    ) external view virtual returns (address) {
        return _accounts[index];
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Add an account to the internal accounts array and center registry
    /// @param account The account address to add
    function _addAccount(address account) internal virtual {
        _accounts.push(account);
        ILOVE20ExtensionCenter(center()).addAccount(
            tokenAddress,
            actionId,
            account
        );
    }

    /// @dev Remove an account from the internal accounts array and center registry
    /// @param account The account address to remove
    function _removeAccount(address account) internal virtual {
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

