// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "../ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "../ExtensionRewardMixin.sol";
import {ExtensionVerificationMixin} from "../ExtensionVerificationMixin.sol";
import {
    ExtensionScoreBasedRewardMixin
} from "../ExtensionScoreBasedRewardMixin.sol";
import {ExtensionJoinMixin} from "../ExtensionJoinMixin.sol";

/// @title ExtensionWithJoin
/// @notice Example: Extension combining Score system with Join functionality
/// @dev This demonstrates how to compose mixins to create a complete extension
///
/// Mixin Composition:
/// - ExtensionCoreMixin: Core functionality (factory, initialization)
/// - ExtensionAccountMixin: Account management
/// - ExtensionRewardMixin: Reward distribution framework
/// - ExtensionVerificationMixin: Verification info management
/// - ExtensionScoreBasedRewardMixin: Score-based reward calculation strategy
/// - ExtensionJoinMixin: Join/withdraw functionality
///
contract ExtensionWithJoin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreBasedRewardMixin,
    ExtensionJoinMixin
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) ExtensionJoinMixin(factory_, joinTokenAddress_, waitingBlocks_) {}

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
    // JOIN/WITHDRAW OVERRIDES
    // ============================================

    /// @notice Join with tokens to participate
    /// @dev Override to add verification result preparation
    /// @param amount The amount of tokens to join with
    /// @param verificationInfos Verification information array
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public override {
        _prepareVerifyResultIfNeeded();
        ExtensionJoinMixin.join(amount, verificationInfos);
    }

    /// @notice Withdraw joined tokens after waiting period
    /// @dev Override to add verification result preparation
    function withdraw() public override {
        _prepareVerifyResultIfNeeded();
        ExtensionJoinMixin.withdraw();
    }

    // ============================================
    // REWARD CLAIMING OVERRIDE
    // ============================================

    /// @notice Claim reward for a specific round
    /// @dev Override to prepare verification results before claiming
    /// @param round The round number to claim reward from
    /// @return reward The amount of reward claimed
    function claimReward(
        uint256 round
    )
        public
        override(ExtensionRewardMixin, ExtensionScoreBasedRewardMixin)
        returns (uint256 reward)
    {
        _prepareVerifyResultIfNeeded();
        return super.claimReward(round);
    }

    // ============================================
    // SCORE CALCULATION - IMPLEMENTATION
    // ============================================

    /// @notice Calculate scores for all accounts
    /// @dev Score = joined amount for each account
    function calculateScores()
        public
        view
        override
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
    /// @dev Score = joined amount
    function calculateScore(
        address account
    ) public view override returns (uint256 total, uint256 score) {
        (total, ) = calculateScores();
        score = _joinInfo[account].amount;
        return (total, score);
    }

    // ============================================
    // VERIFICATION IMPLEMENTATION
    // ============================================

    /// @dev Prepare verification results by calculating and storing scores
    function _prepareVerifyResultIfNeeded() internal override {
        super._prepareVerifyResultIfNeeded();
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
        return totalJoinedAmount;
    }

    /// @notice Get joined value by account
    function joinedValueByAccount(
        address account
    ) external view returns (uint256) {
        return _joinInfo[account].amount;
    }
}
