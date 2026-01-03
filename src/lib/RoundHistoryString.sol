// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

library RoundHistoryString {
    using ArrayUtils for uint256[];

    error InvalidRound();

    struct History {
        uint256[] changeRounds;
        // round => value
        mapping(uint256 => string) valueByRound;
        // round => isRecorded
        mapping(uint256 => bool) isRecorded;
    }

    function record(
        History storage self,
        uint256 round,
        string memory newValue
    ) internal {
        uint256 len = self.changeRounds.length;
        if (len == 0 || round > self.changeRounds[len - 1]) {
            self.changeRounds.push(round);
            self.isRecorded[round] = true;
        } else if (round < self.changeRounds[len - 1]) {
            revert InvalidRound();
        }
        self.valueByRound[round] = newValue;
    }

    function value(
        History storage self,
        uint256 round
    ) internal view returns (string memory) {
        // Fast path: exact round match
        if (self.isRecorded[round]) {
            return self.valueByRound[round];
        }
        // Slow path: binary search
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : "";
    }

    function latestValue(
        History storage self
    ) internal view returns (string memory) {
        if (self.changeRounds.length == 0) {
            return "";
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }
}
