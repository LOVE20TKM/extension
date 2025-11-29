// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title RoundStringHistory
/// @notice Library for tracking historical string values across rounds with efficient binary search lookup
/// @dev Provides functions to record string values at specific rounds and query historical values
library RoundStringHistory {
    using ArrayUtils for uint256[];

    // ============================================
    // DATA STRUCTURE
    // ============================================

    /// @notice Encapsulates round-based historical string value tracking
    /// @dev Contains both the change rounds array and the value mapping
    struct History {
        uint256[] changeRounds;
        mapping(uint256 => string) valueByRound;
    }

    // ============================================
    // STRUCT-BASED FUNCTIONS
    // ============================================

    /// @notice Record a string value at a specific round
    /// @param self The History storage reference
    /// @param round The round number to record
    /// @param newValue The string value to record
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

    /// @notice Get the string value at a specific round using binary search
    /// @param self The History storage reference
    /// @param round The round number to query
    /// @return The string value at or before the specified round (empty string if no record exists)
    function value(
        History storage self,
        uint256 round
    ) internal view returns (string memory) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : "";
    }

    /// @notice Get the latest recorded string value
    /// @param self The History storage reference
    /// @return The latest string value (empty string if no record exists)
    function latestValue(
        History storage self
    ) internal view returns (string memory) {
        if (self.changeRounds.length == 0) {
            return "";
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }

    /// @notice Get the number of rounds with recorded changes
    /// @param self The History storage reference
    /// @return The count of change rounds
    function changeRoundsCount(
        History storage self
    ) internal view returns (uint256) {
        return self.changeRounds.length;
    }

    /// @notice Get the round number at a specific index
    /// @param self The History storage reference
    /// @param index The index to query
    /// @return The round number at the specified index
    function changeRoundAtIndex(
        History storage self,
        uint256 index
    ) internal view returns (uint256) {
        return self.changeRounds[index];
    }
}
