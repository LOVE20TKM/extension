// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";

abstract contract ExtensionAccountMixin is ExtensionCoreMixin {
    address[] internal _accounts;

    function accounts() external view returns (address[] memory) {
        return _accounts;
    }

    function accountsCount() external view returns (uint256) {
        return _accounts.length;
    }

    function accountAtIndex(uint256 index) external view returns (address) {
        return _accounts[index];
    }

    function _addAccount(address account) internal {
        _accounts.push(account);
        ILOVE20ExtensionCenter(center()).addAccount(
            tokenAddress,
            actionId,
            account
        );
    }

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
