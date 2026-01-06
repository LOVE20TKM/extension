// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {RoundHistoryUint256} from "./RoundHistoryUint256.sol";
import {RoundHistoryAddress} from "./RoundHistoryAddress.sol";

library RoundHistoryAddressSet {
    using RoundHistoryUint256 for RoundHistoryUint256.History;
    using RoundHistoryAddress for RoundHistoryAddress.History;

    struct Storage {
        RoundHistoryUint256.History accountsCountHistory;
        mapping(uint256 => RoundHistoryAddress.History) accountsAtIndexHistory;
        mapping(address => RoundHistoryUint256.History) accountsIndexHistory;
        mapping(address => bool) isAccountAdded;
    }

    function add(
        Storage storage self,
        uint256 round,
        address account
    ) internal {
        if (self.isAccountAdded[account]) {
            return;
        }

        uint256 accountCount = self.accountsCountHistory.latestValue();
        self.accountsAtIndexHistory[accountCount].record(round, account);
        self.accountsIndexHistory[account].record(round, accountCount);
        self.accountsCountHistory.record(round, accountCount + 1);
        self.isAccountAdded[account] = true;
    }

    function remove(
        Storage storage self,
        uint256 round,
        address account
    ) internal {
        uint256 totalCount = self.accountsCountHistory.latestValue();
        if (totalCount == 0) {
            return;
        }

        if (!self.isAccountAdded[account]) {
            return;
        }

        uint256 index = self.accountsIndexHistory[account].latestValue();
        uint256 lastIndex = totalCount - 1;

        if (index != lastIndex) {
            address lastAccount = self
                .accountsAtIndexHistory[lastIndex]
                .latestValue();
            self.accountsAtIndexHistory[index].record(round, lastAccount);
            self.accountsIndexHistory[lastAccount].record(round, index);
        }

        self.accountsAtIndexHistory[lastIndex].record(round, address(0));
        self.accountsCountHistory.record(round, lastIndex);
        self.isAccountAdded[account] = false;
    }

    function contains(
        Storage storage self,
        address account
    ) internal view returns (bool) {
        return self.isAccountAdded[account];
    }

    function containsByRound(
        Storage storage self,
        address account,
        uint256 round
    ) internal view returns (bool) {
        uint256 index = self.accountsIndexHistory[account].value(round);
        address accountAtIndex = self.accountsAtIndexHistory[index].value(
            round
        );
        return account == accountAtIndex;
    }

    function values(
        Storage storage self
    ) internal view returns (address[] memory) {
        uint256 totalCount = self.accountsCountHistory.latestValue();
        address[] memory result = new address[](totalCount);
        for (uint256 i = 0; i < totalCount; i++) {
            result[i] = self.accountsAtIndexHistory[i].latestValue();
        }
        return result;
    }

    function count(Storage storage self) internal view returns (uint256) {
        return self.accountsCountHistory.latestValue();
    }

    function atIndex(
        Storage storage self,
        uint256 index
    ) internal view returns (address) {
        return self.accountsAtIndexHistory[index].latestValue();
    }

    function valuesByRound(
        Storage storage self,
        uint256 round
    ) internal view returns (address[] memory) {
        uint256 totalCount = self.accountsCountHistory.value(round);
        address[] memory result = new address[](totalCount);
        for (uint256 i = 0; i < totalCount; i++) {
            result[i] = self.accountsAtIndexHistory[i].value(round);
        }
        return result;
    }

    function countByRound(
        Storage storage self,
        uint256 round
    ) internal view returns (uint256) {
        return self.accountsCountHistory.value(round);
    }

    function atIndexByRound(
        Storage storage self,
        uint256 index,
        uint256 round
    ) internal view returns (address) {
        return self.accountsAtIndexHistory[index].value(round);
    }
}
