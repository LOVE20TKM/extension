// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title RoundHistoryAddressArray
/// @notice Library for tracking historical address array values across rounds
library RoundHistoryAddressArray {
    using ArrayUtils for uint256[];

    struct History {
        uint256[] changeRounds;
        mapping(uint256 => address[]) valueByRound;
    }

    /// @notice Record address array at a specific round
    function record(
        History storage self,
        uint256 round,
        address[] memory newValues
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

    /// @notice Get address array at a specific round using binary search
    function values(
        History storage self,
        uint256 round
    ) internal view returns (address[] memory) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : new address[](0);
    }

    /// @notice Get the latest recorded address array
    function latestValues(
        History storage self
    ) internal view returns (address[] memory) {
        if (self.changeRounds.length == 0) {
            return new address[](0);
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }

    /// @notice Add address if not exists
    function add(History storage self, uint256 round, address value) internal {
        address[] memory arr = values(self, round);
        for (uint256 i; i < arr.length; ) {
            if (arr[i] == value) return;
            unchecked {
                ++i;
            }
        }
        address[] memory updated = new address[](arr.length + 1);
        for (uint256 i; i < arr.length; ) {
            updated[i] = arr[i];
            unchecked {
                ++i;
            }
        }
        updated[arr.length] = value;
        record(self, round, updated);
    }

    /// @notice Remove address, returns true if removed
    function remove(
        History storage self,
        uint256 round,
        address value
    ) internal returns (bool) {
        address[] memory arr = values(self, round);
        for (uint256 i; i < arr.length; ) {
            if (arr[i] == value) {
                address[] memory updated = new address[](arr.length - 1);
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
