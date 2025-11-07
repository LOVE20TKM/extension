// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "./ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "./ExtensionRewardMixin.sol";

/// @title ExtensionScoreMixin
/// @notice Mixin for score-based reward distribution
/// @dev Provides score calculation and storage functionality
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// To use this mixin, you MUST override the following functions:
///
/// 1. calculateScores() - Calculate scores for all accounts
/// 2. calculateScore(address) - Calculate score for specific account
///
/// Example:
/// ```
/// function calculateScores() public view override
///     returns (uint256 total, uint256[] memory scores)
/// {
///     scores = new uint256[](_accounts.length);
///     for (uint256 i = 0; i < _accounts.length; i++) {
///         uint256 score = /* your scoring logic */;
///         scores[i] = score;
///         total += score;
///     }
///     return (total, scores);
/// }
/// ```
/// ==============================================================
///
abstract contract ExtensionScoreMixin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin
{
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev round => totalScore
    mapping(uint256 => uint256) internal _totalScore;

    /// @dev round => account[] - snapshot of accounts at the end of each round
    mapping(uint256 => address[]) internal _accountsByRound;

    /// @dev round => score[] - scores corresponding to accountsByRound
    mapping(uint256 => uint256[]) internal _scores;

    /// @dev round => account => score - quick lookup for account scores
    mapping(uint256 => mapping(address => uint256)) internal _scoreByAccount;

    /// @dev round => bool - whether verification result has been generated for this round
    mapping(uint256 => bool) internal _verificationGenerated;

    // ============================================
    // ABSTRACT FUNCTIONS - MUST BE IMPLEMENTED
    // ============================================

    /// @notice Calculate scores for all eligible accounts
    /// @dev ⚠️ REQUIRED: Must be implemented by child contracts
    /// @return total The total score across all accounts
    /// @return scores Array of individual scores (scores[i] corresponds to _accounts[i])
    function calculateScores()
        public
        view
        virtual
        returns (uint256 total, uint256[] memory scores);

    /// @notice Calculate score for a specific account
    /// @dev ⚠️ REQUIRED: Must be implemented by child contracts
    /// @param account The account address to calculate score for
    /// @return total The total score across all accounts
    /// @return score The score for the specified account
    function calculateScore(
        address account
    ) public view virtual returns (uint256 total, uint256 score);

    // ============================================
    // REWARD CALCULATION IMPLEMENTATION
    // ============================================

    /// @inheritdoc ExtensionRewardMixin
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual override returns (uint256 reward, bool isMinted) {
        // Check if already claimed
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        // Can't know the reward if verify phase is not finished
        if (round >= _verify.currentRound()) {
            return (0, false);
        }

        // Get total action reward for this round
        (uint256 totalActionReward, ) = _mint.actionRewardByActionIdByAccount(
            tokenAddress,
            round,
            actionId,
            address(this)
        );

        // Get scores from verification result
        uint256 total = _totalScore[round];
        if (total == 0) {
            // No verification result generated for this round
            return (0, false);
        }

        // Scores already verified and stored
        uint256 score = _scoreByAccount[round][account];

        // Calculate proportional reward
        return ((totalActionReward * score) / total, false);
    }

    // ============================================
    // VERIFICATION IMPLEMENTATION
    // ============================================

    /// @inheritdoc ExtensionRewardMixin
    /// @dev Generate verification result for current round if not already generated
    function _prepareVerifyResultIfNeeded() internal virtual override {
        uint256 currentRound = _verify.currentRound();

        // Skip if already generated for this round
        if (_verificationGenerated[currentRound]) {
            return;
        }

        // Mark as generated before calculating
        _verificationGenerated[currentRound] = true;

        // Calculate and store scores for current round
        (
            uint256 totalCalculated,
            uint256[] memory scoresCalculated
        ) = calculateScores();
        _totalScore[currentRound] = totalCalculated;
        _scores[currentRound] = scoresCalculated;

        // Save accounts snapshot for current round
        _accountsByRound[currentRound] = _accounts;

        // Build score lookup mapping for current round
        for (uint256 i = 0; i < _accounts.length; i++) {
            _scoreByAccount[currentRound][_accounts[i]] = scoresCalculated[i];
        }
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get the total score for a specific round
    function totalScore(uint256 round) external view returns (uint256) {
        return _totalScore[round];
    }

    /// @notice Get all accounts for a specific round
    function accountsByRound(
        uint256 round
    ) external view returns (address[] memory result) {
        result = _accountsByRound[round];
        if (result.length == 0) {
            if (round > _join.currentRound()) {
                return new address[](0);
            } else {
                return _accounts;
            }
        }
        return result;
    }

    /// @notice Get the count of verified accounts for a specific round
    function accountsByRoundCount(
        uint256 round
    ) external view returns (uint256) {
        return _accountsByRound[round].length;
    }

    /// @notice Get a verified account at a specific index for a round
    function accountsByRoundAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (address) {
        return _accountsByRound[round][index];
    }

    /// @notice Get all scores for a specific round
    function scores(uint256 round) external view returns (uint256[] memory) {
        return _scores[round];
    }

    /// @notice Get the count of scores for a specific round
    function scoresCount(uint256 round) external view returns (uint256) {
        return _scores[round].length;
    }

    /// @notice Get a score at a specific index for a round
    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (uint256) {
        return _scores[round][index];
    }

    /// @notice Get the score for a specific account in a round
    function scoreByAccount(
        uint256 round,
        address account
    ) external view returns (uint256) {
        return _scoreByAccount[round][account];
    }
}
