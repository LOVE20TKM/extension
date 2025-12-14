// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title RoundHistoryAddress
/// @notice Library for tracking historical address values across rounds with efficient binary search lookup
/// @dev Provides functions to record addresses at specific rounds and query historical values
library RoundHistoryAddress {
    using ArrayUtils for uint256[];

    // ============================================
    // DATA STRUCTURE
    // ============================================

    /// @notice Encapsulates round-based historical address tracking
    /// @dev Contains both the change rounds array and the value mapping
    struct History {
        uint256[] changeRounds;
        mapping(uint256 => address) valueByRound;
    }

    // ============================================
    // STRUCT-BASED FUNCTIONS
    // ============================================

    /// @notice Record an address at a specific round
    /// @param self The History storage reference
    /// @param round The round number to record
    /// @param newValue The address to record
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
    }

    /// @notice Get the address at a specific round using binary search
    /// @param self The History storage reference
    /// @param round The round number to query
    /// @return The address at or before the specified round (address(0) if no record exists)
    function value(
        History storage self,
        uint256 round
    ) internal view returns (address) {
        (bool found, uint256 nearestRound) = self
            .changeRounds
            .findLeftNearestOrEqualValue(round);
        return found ? self.valueByRound[nearestRound] : address(0);
    }

    /// @notice Get the latest recorded address
    /// @param self The History storage reference
    /// @return The latest address (address(0) if no record exists)
    function latestValue(History storage self) internal view returns (address) {
        if (self.changeRounds.length == 0) {
            return address(0);
        }
        uint256 latestRound = self.changeRounds[self.changeRounds.length - 1];
        return self.valueByRound[latestRound];
    }
}
