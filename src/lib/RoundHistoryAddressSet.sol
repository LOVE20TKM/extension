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

    function addAccount(
        Storage storage self,
        address account,
        uint256 currentRound
    ) internal {
        if (self.isAccountAdded[account]) {
            return;
        }

        uint256 accountCount = self.accountsCountHistory.latestValue();
        self.accountsAtIndexHistory[accountCount].record(currentRound, account);
        self.accountsIndexHistory[account].record(currentRound, accountCount);
        self.accountsCountHistory.record(currentRound, accountCount + 1);
        self.isAccountAdded[account] = true;
    }

    function removeAccount(
        Storage storage self,
        address account,
        uint256 currentRound
    ) internal {
        uint256 count = self.accountsCountHistory.latestValue();
        if (count == 0) {
            return;
        }

        if (!self.isAccountAdded[account]) {
            return;
        }

        uint256 index = self.accountsIndexHistory[account].latestValue();
        uint256 lastIndex = count - 1;

        if (index != lastIndex) {
            address lastAccount = self
                .accountsAtIndexHistory[lastIndex]
                .latestValue();
            self.accountsAtIndexHistory[index].record(
                currentRound,
                lastAccount
            );
            self.accountsIndexHistory[lastAccount].record(currentRound, index);
        }

        self.accountsAtIndexHistory[lastIndex].record(currentRound, address(0));
        self.accountsCountHistory.record(currentRound, lastIndex);
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

    function accounts(
        Storage storage self
    ) internal view returns (address[] memory) {
        uint256 count = self.accountsCountHistory.latestValue();
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = self.accountsAtIndexHistory[i].latestValue();
        }
        return result;
    }

    function accountsCount(
        Storage storage self
    ) internal view returns (uint256) {
        return self.accountsCountHistory.latestValue();
    }

    function accountsAtIndex(
        Storage storage self,
        uint256 index
    ) internal view returns (address) {
        return self.accountsAtIndexHistory[index].latestValue();
    }

    function accountsByRound(
        Storage storage self,
        uint256 round
    ) internal view returns (address[] memory) {
        uint256 count = self.accountsCountHistory.value(round);
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = self.accountsAtIndexHistory[i].value(round);
        }
        return result;
    }

    function accountsCountByRound(
        Storage storage self,
        uint256 round
    ) internal view returns (uint256) {
        return self.accountsCountHistory.value(round);
    }

    function accountsByRoundAtIndex(
        Storage storage self,
        uint256 index,
        uint256 round
    ) internal view returns (address) {
        return self.accountsAtIndexHistory[index].value(round);
    }
}
