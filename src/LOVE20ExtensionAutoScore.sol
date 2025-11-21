// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionBase} from "./LOVE20ExtensionBase.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";
import {IExtensionReward} from "./interface/base/IExtensionReward.sol";
import {
    ILOVE20ExtensionAutoScore
} from "./interface/ILOVE20ExtensionAutoScore.sol";

/// @title LOVE20ExtensionAutoScore
/// @notice Abstract base contract for auto score-based LOVE20 extensions
/// @dev Provides common score calculation and reward distribution logic
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// To implement this contract, you MUST override the following functions:
///
/// 1. calculateScores() - Calculate scores for all accounts
///    - Should iterate through _accounts array
///    - Return total score and array of individual scores
///
/// 2. calculateScore(address) - Calculate score for specific account
///    - Should calculate individual account's score
///    - Return total score and account's score
///
/// Example Implementation:
/// ```
/// function calculateScores() public view override returns (uint256 total, uint256[] memory scores) {
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
abstract contract LOVE20ExtensionAutoScore is
    LOVE20ExtensionBase,
    ILOVE20ExtensionAutoScore
{
    // ============================================
    // STATE VARIABLES - SCORE SYSTEM
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
    // CONSTRUCTOR
    // ============================================

    constructor(address factory_) LOVE20ExtensionBase(factory_) {}

    // ============================================
    // ⚠️  ABSTRACT METHODS - MUST BE IMPLEMENTED ⚠️
    // ============================================
    //
    // Child contracts MUST implement these two functions.
    // These functions define the scoring logic for your extension.
    //

    /// @notice Calculate scores for all eligible accounts
    /// @dev ⚠️ REQUIRED: Must be implemented by child contracts
    ///
    /// Implementation requirements:
    /// - Iterate through all accounts in _accounts array
    /// - Calculate individual score for each account based on your logic
    /// - Sum all scores to get the total
    /// - Return both total and array of individual scores
    ///
    /// @custom:must-implement Child contracts must override this function
    /// @custom:security Ensure scores array length matches _accounts.length
    ///
    /// @return total The total score across all accounts
    /// @return scores Array of individual scores (scores[i] corresponds to _accounts[i])
    function calculateScores()
        public
        view
        virtual
        returns (uint256 total, uint256[] memory scores);

    /// @notice Calculate score for a specific account
    /// @dev ⚠️ REQUIRED: Must be implemented by child contracts
    ///
    /// Implementation requirements:
    /// - Calculate the score for the given account
    /// - Calculate total score across all accounts (for proportion calculation)
    /// - Can call calculateScores() internally and filter result
    ///
    /// @custom:must-implement Child contracts must override this function
    ///
    /// @param account The account address to calculate score for
    /// @return total The total score across all accounts
    /// @return score The score for the specified account
    function calculateScore(
        address account
    ) public view virtual returns (uint256 total, uint256 score);

    // ============================================
    // REWARD CALCULATION - TEMPLATE METHOD
    // ============================================

    /// @inheritdoc LOVE20ExtensionBase
    function rewardByAccount(
        uint256 round,
        address account
    )
        public
        view
        virtual
        override(IExtensionReward, LOVE20ExtensionBase)
        returns (uint256 reward, bool isMinted)
    {
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
        // According to the requirement: if verification result is not generated for a round,
        // no reward distribution should be performed
        uint256 total = _totalScore[round];
        if (total == 0) {
            // No verification result generated for this round, return 0 reward
            return (0, false);
        }

        // Scores already verified and stored
        uint256 score = _scoreByAccount[round][account];

        // Calculate proportional reward
        return ((totalActionReward * score) / total, false);
    }

    // ============================================
    // VERIFICATION - TEMPLATE METHOD
    // ============================================

    /// @inheritdoc LOVE20ExtensionBase
    /// @dev Generate verification result for current round if not already generated
    ///      Uses calculateScores() to compute and store scores for all accounts
    ///      Subclasses can override to customize verification logic
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
    // VIEW FUNCTIONS - SCORE DATA
    // ============================================

    /// @notice Get the total score for a specific round
    /// @param round The round number
    /// @return The total score
    function totalScore(uint256 round) external view virtual returns (uint256) {
        return _totalScore[round];
    }

    /// @notice Get all accounts for a specific round
    /// @param round The round number
    /// @return result The array of account addresses
    function accountsByRound(
        uint256 round
    ) external view virtual returns (address[] memory result) {
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
    /// @param round The round number
    /// @return The number of verified accounts
    function accountsByRoundCount(
        uint256 round
    ) external view virtual returns (uint256) {
        return _accountsByRound[round].length;
    }

    /// @notice Get a verified account at a specific index for a round
    /// @param round The round number
    /// @param index The index in the verified accounts array
    /// @return The account address
    function accountsByRoundAtIndex(
        uint256 round,
        uint256 index
    ) external view virtual returns (address) {
        return _accountsByRound[round][index];
    }

    /// @notice Get all scores for a specific round
    /// @param round The round number
    /// @return Array of scores
    function scores(
        uint256 round
    ) external view virtual returns (uint256[] memory) {
        return _scores[round];
    }

    /// @notice Get the count of scores for a specific round
    /// @param round The round number
    /// @return The number of scores
    function scoresCount(
        uint256 round
    ) external view virtual returns (uint256) {
        return _scores[round].length;
    }

    /// @notice Get a score at a specific index for a round
    /// @param round The round number
    /// @param index The index in the scores array
    /// @return The score value
    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view virtual returns (uint256) {
        return _scores[round][index];
    }

    /// @notice Get the score for a specific account in a round
    /// @param round The round number
    /// @param account The account address
    /// @return The account's score
    function scoreByAccount(
        uint256 round,
        address account
    ) external view virtual returns (uint256) {
        return _scoreByAccount[round][account];
    }
}
