// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    LOVE20ExtensionAutoScoreJoin
} from "../LOVE20ExtensionAutoScoreJoin.sol";
import {LOVE20ExtensionAutoScore} from "../LOVE20ExtensionAutoScore.sol";
import {
    ILOVE20ExtensionAutoScore
} from "../interface/ILOVE20ExtensionAutoScore.sol";

/// @title LOVE20ExtensionSimpleJoin
/// @notice Example implementation of LOVE20ExtensionAutoScoreJoin
/// @dev Simple implementation where score equals joined amount
contract LOVE20ExtensionSimpleJoin is LOVE20ExtensionAutoScoreJoin {
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the simple join extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionAutoScoreJoin(
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
        override(LOVE20ExtensionAutoScore, ILOVE20ExtensionAutoScore)
        returns (uint256 total, uint256[] memory scores)
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            uint256 score = _joinInfo[_accounts[i]].amount;
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
    )
        public
        view
        override(LOVE20ExtensionAutoScore, ILOVE20ExtensionAutoScore)
        returns (uint256 total, uint256 score)
    {
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
