// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

library RoundHistoryUint256 {
    using ArrayUtils for uint256[];

    struct History {
        uint256[] changeRounds;
        mapping(uint256 => uint256) valueByRound;
    }

    function record(
        History storage self,
        uint256 round,
        uint256 newValue
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
    ) internal view returns (uint256) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : 0;
    }

    function latestValue(History storage self) internal view returns (uint256) {
        if (self.changeRounds.length == 0) {
            return 0;
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }
}
