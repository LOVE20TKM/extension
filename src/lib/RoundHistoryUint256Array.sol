// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

library RoundHistoryUint256Array {
    using ArrayUtils for uint256[];

    error InvalidRound();

    struct History {
        uint256[] changeRounds;
        // round => values
        mapping(uint256 => uint256[]) valueByRound;
        // round => isRecorded
        mapping(uint256 => bool) isRecorded;
    }

    function record(
        History storage self,
        uint256 round,
        uint256[] memory newValues
    ) internal {
        uint256 len = self.changeRounds.length;
        if (len == 0 || round > self.changeRounds[len - 1]) {
            self.changeRounds.push(round);
            self.isRecorded[round] = true;
        } else if (round < self.changeRounds[len - 1]) {
            revert InvalidRound();
        }
        self.valueByRound[round] = newValues;
    }

    function values(
        History storage self,
        uint256 round
    ) internal view returns (uint256[] memory) {
        // Fast path: exact round match
        if (self.isRecorded[round]) {
            return self.valueByRound[round];
        }
        // Slow path: binary search
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : new uint256[](0);
    }

    function latestValues(
        History storage self
    ) internal view returns (uint256[] memory) {
        uint256 len = self.changeRounds.length;
        if (len == 0) {
            return new uint256[](0);
        }
        uint256 latestRound = self.changeRounds[len - 1];
        return self.valueByRound[latestRound];
    }

    function add(History storage self, uint256 round, uint256 value) internal {
        uint256[] memory arr = values(self, round);
        uint256 arrLen = arr.length;
        for (uint256 i; i < arrLen; ) {
            if (arr[i] == value) return;
            unchecked {
                ++i;
            }
        }
        uint256[] memory updated = new uint256[](arrLen + 1);
        for (uint256 i; i < arrLen; ) {
            updated[i] = arr[i];
            unchecked {
                ++i;
            }
        }
        updated[arrLen] = value;
        record(self, round, updated);
    }

    function remove(
        History storage self,
        uint256 round,
        uint256 value
    ) internal returns (bool) {
        uint256[] memory arr = values(self, round);
        uint256 arrLen = arr.length;
        for (uint256 i; i < arrLen; ) {
            if (arr[i] == value) {
                uint256 newLen = arrLen - 1;
                uint256[] memory updated = new uint256[](newLen);
                for (uint256 j; j < i; ) {
                    updated[j] = arr[j];
                    unchecked {
                        ++j;
                    }
                }
                for (uint256 j = i + 1; j < arrLen; ) {
                    updated[j - 1] = arr[j];
                    unchecked {
                        ++j;
                    }
                }
                record(self, round, updated);
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }
}
