// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

library RoundHistoryString {
    using ArrayUtils for uint256[];

    struct History {
        uint256[] changeRounds;
        mapping(uint256 => string) valueByRound;
    }

    function record(
        History storage self,
        uint256 round,
        string memory newValue
    ) internal {
        if (
            self.changeRounds.length == 0 ||
            self.changeRounds[self.changeRounds.length - 1] != round
        ) {
            self.changeRounds.push(round);
        }
        self.valueByRound[round] = newValue;
    }

    function value(
        History storage self,
        uint256 round
    ) internal view returns (string memory) {
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

    function changeRoundsCount(
        History storage self
    ) internal view returns (uint256) {
        return self.changeRounds.length;
    }

    function changeRoundAtIndex(
        History storage self,
        uint256 index
    ) internal view returns (uint256) {
        return self.changeRounds[index];
    }
}
