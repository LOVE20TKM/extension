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
        uint256[] memory newValue
    ) internal {
        if (
            self.changeRounds.length == 0 ||
            self.changeRounds[self.changeRounds.length - 1] != round
        ) {
            self.changeRounds.push(round);
        }
        delete self.valueByRound[round];
        for (uint256 i = 0; i < newValue.length; i++) {
            self.valueByRound[round].push(newValue[i]);
        }
    }

    /// @notice Get uint256 array at a specific round using binary search
    function value(
        History storage self,
        uint256 round
    ) internal view returns (uint256[] memory) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : new uint256[](0);
    }

    /// @notice Get the latest recorded uint256 array
    function latestValue(
        History storage self
    ) internal view returns (uint256[] memory) {
        if (self.changeRounds.length == 0) {
            return new uint256[](0);
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }
}
