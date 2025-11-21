// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionBaseTokenJoin} from "./LOVE20ExtensionBaseTokenJoin.sol";
import {TokenJoin} from "./base/TokenJoin.sol";
import {IExtensionReward} from "./interface/base/IExtensionReward.sol";
import {ExtensionReward} from "./base/ExtensionReward.sol";
import {
    ILOVE20ExtensionTokenJoinAuto
} from "./interface/ILOVE20ExtensionTokenJoinAuto.sol";
import {ITokenJoin} from "./interface/base/ITokenJoin.sol";

/// @title LOVE20ExtensionBaseTokenJoinAuto
/// @notice Abstract base contract for auto score-based token join LOVE20 extensions
/// @dev Must implement calculateScores() and calculateScore() to define scoring logic
abstract contract LOVE20ExtensionBaseTokenJoinAuto is
    LOVE20ExtensionBaseTokenJoin,
    ILOVE20ExtensionTokenJoinAuto
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

    /// @notice Initialize the token join auto score extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoin(
            factory_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {
        // LOVE20ExtensionBaseTokenJoin handles all initialization
    }

    // ============================================
    // ABSTRACT METHODS - MUST BE IMPLEMENTED
    // ============================================

    /// @notice Calculate scores for all accounts
    /// @param total Total score across all accounts
    /// @param scores Individual scores array (scores[i] for _accounts[i])
    function calculateScores()
        public
        view
        virtual
        returns (uint256 total, uint256[] memory scores);

    /// @notice Calculate score for specific account
    /// @param account Account address
    /// @return total Total score across all accounts
    /// @return score Score for the specified account
    function calculateScore(
        address account
    ) public view virtual returns (uint256 total, uint256 score);

    // ============================================
    // USER OPERATIONS - OVERRIDE WITH VERIFICATION
    // ============================================

    /// @inheritdoc ITokenJoin
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual override(ITokenJoin, TokenJoin) {
        _prepareVerifyResultIfNeeded();
        super.join(amount, verificationInfos);
    }

    /// @inheritdoc ITokenJoin
    function withdraw() public virtual override(ITokenJoin, TokenJoin) {
        _prepareVerifyResultIfNeeded();
        super.withdraw();
    }

    // ============================================
    // REWARD CALCULATION - TEMPLATE METHOD
    // ============================================

    /// @inheritdoc IExtensionReward
    function claimReward(
        uint256 round
    )
        public
        virtual
        override(IExtensionReward, ExtensionReward)
        returns (uint256 reward)
    {
        _prepareVerifyResultIfNeeded();
        return super.claimReward(round);
    }

    /// @inheritdoc ExtensionReward
    function rewardByAccount(
        uint256 round,
        address account
    )
        public
        view
        virtual
        override(IExtensionReward, ExtensionReward)
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

    /// @dev Generate and store verification result for current round
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
    // VIEW FUNCTIONS - SCORE DATA
    // ============================================

    function totalScore(uint256 round) external view virtual returns (uint256) {
        return _totalScore[round];
    }

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

    function accountsByRoundCount(
        uint256 round
    ) external view virtual returns (uint256) {
        return _accountsByRound[round].length;
    }

    function accountsByRoundAtIndex(
        uint256 round,
        uint256 index
    ) external view virtual returns (address) {
        return _accountsByRound[round][index];
    }

    function scores(
        uint256 round
    ) external view virtual returns (uint256[] memory) {
        return _scores[round];
    }

    function scoresCount(
        uint256 round
    ) external view virtual returns (uint256) {
        return _scores[round].length;
    }

    function scoresAtIndex(
        uint256 round,
        uint256 index
    ) external view virtual returns (uint256) {
        return _scores[round][index];
    }

    function scoreByAccount(
        uint256 round,
        address account
    ) external view virtual returns (uint256) {
        return _scoreByAccount[round][account];
    }
}

