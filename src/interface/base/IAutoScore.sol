// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/// @title IAutoScore
/// @notice Interface for auto score calculation functionality
/// @dev Defines score calculation and storage for round-based verification
interface IAutoScore {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when trying to access snapshot data for a future round
    error NoSnapshotForFutureRound();

    // ============================================
    // SCORE CALCULATION
    // ============================================

    function calculateScores()
        external
        view
        returns (uint256 total, uint256[] memory scores);

    function calculateScore(
        address account
    ) external view returns (uint256 total, uint256 score);

    function totalScore(uint256 round) external view returns (uint256);

    function accountsByRound(
        uint256 round
    ) external view returns (address[] memory);

    function accountsByRoundCount(
        uint256 round
    ) external view returns (uint256);

    function accountsByRoundAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (address);

    function scores(uint256 round) external view returns (uint256[] memory);

    function scoresCount(uint256 round) external view returns (uint256);

    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (uint256);

    function scoreByAccount(
        uint256 round,
        address account
    ) external view returns (uint256);
}
