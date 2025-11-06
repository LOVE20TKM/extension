// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    LOVE20ExtensionAutoScoreStake
} from "../LOVE20ExtensionAutoScoreStake.sol";
import {LOVE20ExtensionAutoScore} from "../LOVE20ExtensionAutoScore.sol";
import {
    ILOVE20ExtensionAutoScore
} from "../interface/ILOVE20ExtensionAutoScore.sol";

/// @title LOVE20ExtensionSimpleStake
/// @notice Example implementation of LOVE20ExtensionAutoScoreStake
/// @dev Simple implementation where score equals staked amount
contract LOVE20ExtensionSimpleStake is LOVE20ExtensionAutoScoreStake {
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the simple stake extension
    /// @param factory_ The factory address
    /// @param stakeTokenAddress_ The token that can be staked
    /// @param waitingPhases_ Number of phases to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required to stake
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    )
        LOVE20ExtensionAutoScoreStake(
            factory_,
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        )
    {}

    // ============================================
    // SCORE CALCULATION - REQUIRED IMPLEMENTATION
    // ============================================

    /// @notice Calculate scores for all accounts
    /// @dev Score equals the staked amount (1:1 ratio)
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
            uint256 score = _stakeInfo[_accounts[i]].amount;
            scores[i] = score;
            total += score;
        }
        return (total, scores);
    }

    /// @notice Calculate score for a specific account
    /// @dev Score equals the staked amount (1:1 ratio)
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
        score = _stakeInfo[account].amount;
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
    /// @dev Returns the total amount of tokens staked by all accounts
    /// @return The total joined value
    function joinedValue() external view override returns (uint256) {
        return totalStakedAmount;
    }

    /// @notice Get the joined value for a specific account
    /// @param account The account address to query
    /// @return The joined value for the account
    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        return _stakeInfo[account].amount;
    }
}
