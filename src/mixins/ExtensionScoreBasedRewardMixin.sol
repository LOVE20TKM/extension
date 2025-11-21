// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "./ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "./ExtensionRewardMixin.sol";

/// @title ExtensionScoreBasedRewardMixin
/// @notice Score-based proportional reward distribution strategy
/// @dev Implements a reward distribution system where rewards are allocated proportionally based on scores
///
/// ARCHITECTURE:
/// This mixin extends ExtensionRewardMixin and implements a specific reward distribution strategy:
/// - Each account has a score
/// - Rewards are distributed proportionally: accountReward = totalReward * accountScore / totalScore
///
/// RESPONSIBILITIES:
/// - Store scores by round (_totalScore, _scores, _scoreByAccount)
/// - Snapshot accounts at the end of each round
/// - Calculate proportional rewards based on scores
/// - Implement rewardByAccount() from ExtensionRewardMixin
///
/// EXTENSION POINTS:
/// Derived contracts must implement:
/// - calculateScores() - Calculate scores for all accounts
/// - calculateScore(address) - Calculate score for a specific account
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// To use this mixin, you MUST override the following functions:
///
/// 1. calculateScores() - Calculate scores for all accounts
/// 2. calculateScore(address) - Calculate score for specific account
///
/// Example:
/// ```solidity
/// function calculateScores()
///     public view override
///     returns (uint256 total, uint256[] memory scores)
/// {
///     scores = new uint256[](_accounts.length);
///     for (uint256 i = 0; i < _accounts.length; i++) {
///         scores[i] = _joinInfo[_accounts[i]].amount;
///         total += scores[i];
///     }
/// }
/// ```
/// ==============================================================
abstract contract ExtensionScoreBasedRewardMixin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin
{
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev round => total score for that round
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

    /// @notice Calculate scores for all accounts
    /// @dev Called during verification to snapshot current scores
    /// @return total The sum of all scores
    /// @return scores Array of scores corresponding to _accounts array
    function calculateScores()
        public
        view
        virtual
        returns (uint256 total, uint256[] memory scores);

    /// @notice Calculate score for a specific account
    /// @dev Used for individual score queries
    /// @param account The account address
    /// @return total The sum of all scores
    /// @return score The score for the specified account
    function calculateScore(
        address account
    ) public view virtual returns (uint256 total, uint256 score);

    // ============================================
    // REWARD CALCULATION IMPLEMENTATION
    // ============================================

    /// @notice Claim reward for a specific round
    /// @dev Override to prepare verification results before claiming
    /// @param round The round number to claim reward from
    /// @return reward The amount of reward claimed
    function claimReward(
        uint256 round
    ) public virtual override returns (uint256 reward) {
        _prepareVerifyResultIfNeeded();
        return super.claimReward(round);
    }

    /// @inheritdoc ExtensionRewardMixin
    /// @dev Implements proportional reward distribution based on scores
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual override returns (uint256 reward, bool isMinted) {
        // Check if already claimed
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        // Can't calculate reward if verify phase is not finished
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

        // Get account's score for this round
        uint256 score = _scoreByAccount[round][account];

        // Calculate proportional reward: reward = totalReward * score / totalScore
        return ((totalActionReward * score) / total, false);
    }

    // ============================================
    // VERIFICATION IMPLEMENTATION
    // ============================================

    /// @dev Prepares verification result by calculating and storing scores
    function _prepareVerifyResultIfNeeded() internal virtual {
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

    /// @notice Get total score for a specific round
    /// @param round The round number
    /// @return The total score
    function totalScore(uint256 round) external view returns (uint256) {
        return _totalScore[round];
    }

    /// @notice Get all accounts for a specific round
    /// @param round The round number
    /// @return result Array of account addresses
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

    /// @notice Get number of accounts for a specific round
    /// @param round The round number
    /// @return Number of accounts
    function accountsByRoundCount(
        uint256 round
    ) external view returns (uint256) {
        return _accountsByRound[round].length;
    }

    /// @notice Get account at specific index for a specific round
    /// @param round The round number
    /// @param index The index in the accounts array
    /// @return The account address
    function accountsByRoundAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (address) {
        return _accountsByRound[round][index];
    }

    /// @notice Get all scores for a specific round
    /// @param round The round number
    /// @return Array of scores
    function scores(uint256 round) external view returns (uint256[] memory) {
        return _scores[round];
    }

    /// @notice Get number of scores for a specific round
    /// @param round The round number
    /// @return Number of scores
    function scoresCount(uint256 round) external view returns (uint256) {
        return _scores[round].length;
    }

    /// @notice Get score at specific index for a specific round
    /// @param round The round number
    /// @param index The index in the scores array
    /// @return The score value
    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view returns (uint256) {
        return _scores[round][index];
    }

    /// @notice Get score for a specific account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return The account's score
    function scoreByAccount(
        uint256 round,
        address account
    ) external view returns (uint256) {
        return _scoreByAccount[round][account];
    }
}
