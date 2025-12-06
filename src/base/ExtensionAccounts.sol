// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {IExtensionAccounts} from "../interface/base/IExtensionAccounts.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title ExtensionAccounts
/// @notice Base contract providing account management functionality
/// @dev Implements IExtensionAccounts interface with O(1) account operations using EnumerableSet
abstract contract ExtensionAccounts is ExtensionCore, IExtensionAccounts {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Set of accounts participating in this extension
    EnumerableSet.AddressSet internal _accounts;

    // ============================================
    // IEXTENSIONACCOUNTS INTERFACE
    // ============================================

    /// @inheritdoc IExtensionAccounts
    function accounts() external view virtual returns (address[] memory) {
        return _accounts.values();
    }

    /// @inheritdoc IExtensionAccounts
    function accountsCount() external view virtual returns (uint256) {
        return _accounts.length();
    }

    /// @inheritdoc IExtensionAccounts
    function accountsAtIndex(
        uint256 index
    ) external view virtual returns (address) {
        return _accounts.at(index);
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Add an account to the internal accounts set and center registry
    /// @param account The account address to add
    function _addAccount(address account) internal virtual {
        _accounts.add(account);
        _center.addAccount(tokenAddress, actionId, account);
    }

    /// @dev Remove an account from the internal accounts set and center registry
    /// @param account The account address to remove
    /// @dev Reverts with AccountNotFound if account doesn't exist
    function _removeAccount(address account) internal virtual {
        if (!_accounts.remove(account)) {
            revert IExtensionAccounts.AccountNotFound();
        }
        _center.removeAccount(tokenAddress, actionId, account);
    }
}
