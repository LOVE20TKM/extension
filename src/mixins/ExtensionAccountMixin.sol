// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";
import {IExtensionAccounts} from "../interface/base/IExtensionAccounts.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract ExtensionAccountMixin is
    ExtensionCoreMixin,
    IExtensionAccounts
{
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============================================
    // STATE VARIABLES
    // ============================================

    EnumerableSet.AddressSet internal _accounts;

    function accounts() external view returns (address[] memory) {
        return _accounts.values();
    }

    function accountsCount() external view returns (uint256) {
        return _accounts.length();
    }

    function accountAtIndex(uint256 index) external view returns (address) {
        return _accounts.at(index);
    }

    function _addAccount(address account) internal {
        _accounts.add(account);
        ILOVE20ExtensionCenter(center()).addAccount(
            tokenAddress,
            actionId,
            account
        );
    }

    function _removeAccount(address account) internal {
        if (!_accounts.remove(account)) {
            revert IExtensionAccounts.AccountNotFound();
        }
        ILOVE20ExtensionCenter(center()).removeAccount(
            tokenAddress,
            actionId,
            account
        );
    }
}
