// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Extension} from "./ILOVE20Extension.sol";

/// @title ILOVE20ExtensionAutoScore
/// @notice Interface for auto score-based LOVE20 extensions
/// @dev Extends ILOVE20Extension with score calculation and verification functions
interface ILOVE20ExtensionAutoScore is ILOVE20Extension {
    // ============================================
    // SCORE CALCULATION
    // ============================================

    /// @notice Calculate scores for all eligible accounts
    /// @return total The total score across all accounts
    /// @return scores Array of individual scores
    function calculateScores()
        external
        view
        returns (uint256 total, uint256[] memory scores);

    /// @notice Calculate score for a specific account
    /// @param account The account address to calculate score for
    /// @return total The total score across all accounts
    /// @return score The score for the specified account
    function calculateScore(
        address account
    ) external view returns (uint256 total, uint256 score);

    // ============================================
    // VERIFIED RESULTS
    // ============================================

    /// @notice Get the total score for a specific round
    /// @param round The round number
    /// @return The total score
    function totalScore(uint256 round) external view returns (uint256);

    /// @notice Get all verified accounts for a specific round
    /// @param round The round number
    /// @return Array of verified account addresses
    function accountsByRound(
        uint256 round
    ) external view returns (address[] memory);

    /// @notice Get the count of verified accounts for a specific round
    /// @param round The round number
    /// @return The number of verified accounts
    function accountsByRoundCount(
        uint256 round
    ) external view returns (uint256);

    /// @notice Get a verified account at a specific index for a round
    /// @param round The round number
    /// @param index The index in the verified accounts array
    /// @return The account address
    function accountsByRoundAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (address);

    /// @notice Get all scores for a specific round
    /// @param round The round number
    /// @return Array of scores
    function scores(uint256 round) external view returns (uint256[] memory);

    /// @notice Get the count of scores for a specific round
    /// @param round The round number
    /// @return The number of scores
    function scoresCount(uint256 round) external view returns (uint256);

    /// @notice Get a score at a specific index for a round
    /// @param round The round number
    /// @param index The index in the scores array
    /// @return The score value
    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (uint256);

    /// @notice Get the score for a specific account in a round
    /// @param round The round number
    /// @param account The account address
    /// @return The account's score
    function scoreByAccount(
        uint256 round,
        address account
    ) external view returns (uint256);
}
