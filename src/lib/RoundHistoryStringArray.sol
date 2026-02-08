// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

library RoundHistoryStringArray {
    using ArrayUtils for uint256[];

    error InvalidRound();

    struct History {
        uint256[] changeRounds;
        mapping(uint256 => string[]) valueByRound;
        mapping(uint256 => bool) isRecorded;
    }

    function record(
        History storage self,
        uint256 round,
        string[] memory newValues
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
    ) internal view returns (string[] memory) {
        if (self.isRecorded[round]) {
            return self.valueByRound[round];
        }
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : new string[](0);
    }

    function latestValues(
        History storage self
    ) internal view returns (string[] memory) {
        uint256 len = self.changeRounds.length;
        if (len == 0) {
            return new string[](0);
        }
        uint256 latestRound = self.changeRounds[len - 1];
        return self.valueByRound[latestRound];
    }
}
