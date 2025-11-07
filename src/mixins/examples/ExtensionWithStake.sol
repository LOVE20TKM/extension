// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "../ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "../ExtensionRewardMixin.sol";
import {ExtensionVerificationMixin} from "../ExtensionVerificationMixin.sol";
import {ExtensionScoreMixin} from "../ExtensionScoreMixin.sol";
import {ExtensionStakeMixin} from "../ExtensionStakeMixin.sol";

/// @title ExtensionWithStake
/// @notice Example: Extension combining Score system with Stake functionality
/// @dev This demonstrates how to compose mixins to create a complete extension
///
/// Mixin Composition:
/// - ExtensionCoreMixin: Core functionality (factory, initialization)
/// - ExtensionAccountMixin: Account management
/// - ExtensionRewardMixin: Reward distribution
/// - ExtensionVerificationMixin: Verification info management
/// - ExtensionScoreMixin: Score-based reward calculation
/// - ExtensionStakeMixin: Stake/unstake/withdraw functionality
///
contract ExtensionWithStake is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionStakeMixin
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param stakeTokenAddress_ The token that can be staked
    /// @param waitingPhases_ Number of phases to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    )
        ExtensionStakeMixin(
            factory_,
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        )
    {}

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @inheritdoc ExtensionCoreMixin
    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) public override onlyCenter {
        super.initialize(tokenAddress_, actionId_);
    }

    // ============================================
    // SCORE CALCULATION - IMPLEMENTATION
    // ============================================

    /// @notice Calculate scores for all accounts
    /// @dev Score = staked amount for each account
    function calculateScores()
        public
        view
        override
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
    /// @dev Score = staked amount
    function calculateScore(
        address account
    ) public view override returns (uint256 total, uint256 score) {
        (total, ) = calculateScores();
        score = _stakeInfo[account].amount;
        return (total, score);
    }

    // ============================================
    // HOOK OVERRIDES
    // ============================================

    /// @dev Override to resolve conflict between RewardMixin and ScoreMixin
    function _prepareVerifyResultIfNeeded()
        internal
        virtual
        override(ExtensionRewardMixin, ExtensionScoreMixin)
    {
        ExtensionScoreMixin._prepareVerifyResultIfNeeded();
    }

    /// @notice Override stake to add verification result preparation
    function stake(
        uint256 amount,
        string[] memory verificationInfos
    ) public override {
        _prepareVerifyResultIfNeeded();
        _doStake(amount, verificationInfos);
    }

    /// @notice Override unstake to add verification result preparation
    function unstake() public override {
        _prepareVerifyResultIfNeeded();
        _doUnstake();
    }

    /// @notice Override withdraw to add verification result preparation
    function withdraw() public override {
        _prepareVerifyResultIfNeeded();
        _doWithdraw();
    }

    // ============================================
    // JOINED VALUE INTERFACE IMPLEMENTATION
    // ============================================

    /// @notice Check if joined value calculation is supported
    function isJoinedValueCalculated() external pure returns (bool) {
        return true;
    }

    /// @notice Get total joined value
    function joinedValue() external view returns (uint256) {
        return totalStakedAmount;
    }

    /// @notice Get joined value by account
    function joinedValueByAccount(
        address account
    ) external view returns (uint256) {
        return _stakeInfo[account].amount;
    }
}

