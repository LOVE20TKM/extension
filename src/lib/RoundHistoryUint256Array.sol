// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title RoundHistoryUint256Array
/// @notice Library for tracking historical uint256 array values across rounds
library RoundHistoryUint256Array {
    using ArrayUtils for uint256[];

    struct History {
        uint256[] changeRounds;
        mapping(uint256 => uint256[]) valueByRound;
    }

    /// @notice Record uint256 array at a specific round
    function record(
        History storage self,
        uint256 round,
        uint256[] memory newValues
    ) internal {
        if (
            self.changeRounds.length == 0 ||
            self.changeRounds[self.changeRounds.length - 1] != round
        ) {
            self.changeRounds.push(round);
        }
        delete self.valueByRound[round];
        for (uint256 i = 0; i < newValues.length; i++) {
            self.valueByRound[round].push(newValues[i]);
        }
    }

    /// @notice Get uint256 array at a specific round using binary search
    function values(
        History storage self,
        uint256 round
    ) internal view returns (uint256[] memory) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : new uint256[](0);
    }

    /// @notice Get the latest recorded uint256 array
    function latestValues(
        History storage self
    ) internal view returns (uint256[] memory) {
        if (self.changeRounds.length == 0) {
            return new uint256[](0);
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }

    /// @notice Add value if not exists
    function add(History storage self, uint256 round, uint256 value) internal {
        uint256[] memory arr = values(self, round);
        for (uint256 i; i < arr.length; ) {
            if (arr[i] == value) return;
            unchecked {
                ++i;
            }
        }
        uint256[] memory updated = new uint256[](arr.length + 1);
        for (uint256 i; i < arr.length; ) {
            updated[i] = arr[i];
            unchecked {
                ++i;
            }
        }
        updated[arr.length] = value;
        record(self, round, updated);
    }

    /// @notice Remove value, returns true if removed
    function remove(
        History storage self,
        uint256 round,
        uint256 value
    ) internal returns (bool) {
        uint256[] memory arr = values(self, round);
        for (uint256 i; i < arr.length; ) {
            if (arr[i] == value) {
                uint256[] memory updated = new uint256[](arr.length - 1);
                for (uint256 j; j < i; ) {
                    updated[j] = arr[j];
                    unchecked {
                        ++j;
                    }
                }
                for (uint256 j = i + 1; j < arr.length; ) {
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
