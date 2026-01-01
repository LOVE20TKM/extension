// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {RoundHistoryUint256} from "./RoundHistoryUint256.sol";
import {RoundHistoryAddress} from "./RoundHistoryAddress.sol";

library AccountListHistory {
    using RoundHistoryUint256 for RoundHistoryUint256.History;
    using RoundHistoryAddress for RoundHistoryAddress.History;

    struct Storage {
        mapping(address => mapping(uint256 => RoundHistoryUint256.History)) accountsCountHistory;
        mapping(address => mapping(uint256 => mapping(uint256 => RoundHistoryAddress.History))) accountsAtIndexHistory;
        mapping(address => mapping(uint256 => mapping(address => RoundHistoryUint256.History))) accountsIndexHistory;
    }

    function addAccount(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 currentRound
    ) internal {
        uint256 accountCount = self
            .accountsCountHistory[tokenAddress][actionId]
            .latestValue();
        self
            .accountsAtIndexHistory[tokenAddress][actionId][accountCount]
            .record(currentRound, account);
        self.accountsIndexHistory[tokenAddress][actionId][account].record(
            currentRound,
            accountCount
        );
        self.accountsCountHistory[tokenAddress][actionId].record(
            currentRound,
            accountCount + 1
        );
    }

    function removeAccount(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 currentRound
    ) internal {
        uint256 count = self
            .accountsCountHistory[tokenAddress][actionId]
            .latestValue();
        if (count == 0) {
            return;
        }

        uint256 index = self
            .accountsIndexHistory[tokenAddress][actionId][account]
            .latestValue();
        uint256 lastIndex = count - 1;

        if (index != lastIndex) {
            address lastAccount = self
                .accountsAtIndexHistory[tokenAddress][actionId][lastIndex]
                .latestValue();
            self.accountsAtIndexHistory[tokenAddress][actionId][index].record(
                currentRound,
                lastAccount
            );
            self
                .accountsIndexHistory[tokenAddress][actionId][lastAccount]
                .record(currentRound, index);
        }

        self.accountsAtIndexHistory[tokenAddress][actionId][lastIndex].record(
            currentRound,
            address(0)
        );
        self.accountsCountHistory[tokenAddress][actionId].record(
            currentRound,
            lastIndex
        );
        self.accountsIndexHistory[tokenAddress][actionId][account].record(
            currentRound,
            type(uint256).max
        );
    }

    function accounts(
        Storage storage self,
        address tokenAddress,
        uint256 actionId
    ) internal view returns (address[] memory) {
        uint256 count = self
            .accountsCountHistory[tokenAddress][actionId]
            .latestValue();
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = self
                .accountsAtIndexHistory[tokenAddress][actionId][i]
                .latestValue();
        }
        return result;
    }

    function accountsCount(
        Storage storage self,
        address tokenAddress,
        uint256 actionId
    ) internal view returns (uint256) {
        return self.accountsCountHistory[tokenAddress][actionId].latestValue();
    }

    function accountsAtIndex(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) internal view returns (address) {
        return
            self
                .accountsAtIndexHistory[tokenAddress][actionId][index]
                .latestValue();
    }

    function accountsByRound(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) internal view returns (address[] memory) {
        uint256 count = self.accountsCountHistory[tokenAddress][actionId].value(
            round
        );
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = self
                .accountsAtIndexHistory[tokenAddress][actionId][i]
                .value(round);
        }
        return result;
    }

    function accountsCountByRound(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) internal view returns (uint256) {
        return self.accountsCountHistory[tokenAddress][actionId].value(round);
    }

    function accountsByRoundAtIndex(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        uint256 index,
        uint256 round
    ) internal view returns (address) {
        return
            self.accountsAtIndexHistory[tokenAddress][actionId][index].value(
                round
            );
    }

    function accountIndex(
        Storage storage self,
        address tokenAddress,
        uint256 actionId,
        address account
    ) internal view returns (uint256) {
        return
            self
                .accountsIndexHistory[tokenAddress][actionId][account]
                .latestValue();
    }
}
