// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    LOVE20ExtensionBaseTokenJoinAuto
} from "../LOVE20ExtensionBaseTokenJoinAuto.sol";
import {
    ILOVE20ExtensionTokenJoinAuto
} from "../interface/ILOVE20ExtensionTokenJoinAuto.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title ExampleTokenJoinAuto
/// @notice Example implementation of LOVE20ExtensionBaseTokenJoinAuto
/// @dev Simple implementation where score equals joined amount
contract ExampleTokenJoinAuto is LOVE20ExtensionBaseTokenJoinAuto {
    using EnumerableSet for EnumerableSet.AddressSet;
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the example token join auto extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoinAuto(
            factory_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    // ============================================
    // SCORE CALCULATION - REQUIRED IMPLEMENTATION
    // ============================================

    /// @notice Calculate scores for all accounts
    /// @dev Score equals the joined amount (1:1 ratio)
    /// @return total The total score across all accounts
    /// @return scores Array of individual scores
    function calculateScores()
        public
        view
        override
        returns (uint256 total, uint256[] memory scores)
    {
        uint256 accountsCount = _accounts.length();
        scores = new uint256[](accountsCount);
        for (uint256 i = 0; i < accountsCount; i++) {
            uint256 score = _joinInfo[_accounts.at(i)].amount;
            scores[i] = score;
            total += score;
        }
        return (total, scores);
    }

    /// @notice Calculate score for a specific account
    /// @dev Score equals the joined amount (1:1 ratio)
    /// @param account The account address to calculate score for
    /// @return total The total score across all accounts
    /// @return score The score for the specified account
    function calculateScore(
        address account
    ) public view override returns (uint256 total, uint256 score) {
        (total, ) = calculateScores();
        score = _joinInfo[account].amount;
        return (total, score);
    }

    // ============================================
    // JOINED VALUE CALCULATION - REQUIRED IMPLEMENTATION
    // ============================================

    /// @notice Check if joined value is calculated (always true for this implementation)
    /// @return Always returns true
    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    /// @notice Get the total joined value
    /// @dev Returns the total amount of tokens joined by all accounts
    /// @return The total joined value
    function joinedValue() external view override returns (uint256) {
        return totalJoinedAmount;
    }

    /// @notice Get the joined value for a specific account
    /// @param account The account address to query
    /// @return The joined value for the account
    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        return _joinInfo[account].amount;
    }
}
