// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title RoundHistoryUint256
/// @notice Library for tracking historical values across rounds with efficient binary search lookup
/// @dev Provides functions to record values at specific rounds and query historical values
library RoundHistoryUint256 {
    using ArrayUtils for uint256[];

    // ============================================
    // DATA STRUCTURE
    // ============================================

    /// @notice Encapsulates round-based historical value tracking
    /// @dev Contains both the change rounds array and the value mapping
    struct History {
        uint256[] changeRounds;
        mapping(uint256 => uint256) valueByRound;
    }

    // ============================================
    // STRUCT-BASED FUNCTIONS
    // ============================================

    /// @notice Record a value at a specific round
    /// @param self The History storage reference
    /// @param round The round number to record
    /// @param newValue The value to record
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

    /// @notice Get the value at a specific round using binary search
    /// @param self The History storage reference
    /// @param round The round number to query
    /// @return The value at or before the specified round (0 if no record exists)
    function value(
        History storage self,
        uint256 round
    ) internal view returns (uint256) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : 0;
    }

    /// @notice Get the latest recorded value
    /// @param self The History storage reference
    /// @return The latest value (0 if no record exists)
    function latestValue(History storage self) internal view returns (uint256) {
        if (self.changeRounds.length == 0) {
            return 0;
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }
}
