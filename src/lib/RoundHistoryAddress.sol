// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

library RoundHistoryAddress {
    using ArrayUtils for uint256[];

    struct History {
        uint256[] changeRounds;
        mapping(uint256 => address) valueByRound;
        mapping(uint256 => bool) isRecorded;
    }

    function record(
        History storage self,
        uint256 round,
        address newValue
    ) internal {
        if (
            self.changeRounds.length == 0 ||
            self.changeRounds[self.changeRounds.length - 1] != round
        ) {
            self.changeRounds.push(round);
        }
        self.valueByRound[round] = newValue;
        self.isRecorded[round] = true;
    }

    function value(
        History storage self,
        uint256 round
    ) internal view returns (address) {
        // Fast path: exact round match
        if (self.isRecorded[round]) {
            return self.valueByRound[round];
        }
        // Slow path: binary search
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : address(0);
    }

    function latestValue(History storage self) internal view returns (address) {
        if (self.changeRounds.length == 0) {
            return address(0);
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }
}
