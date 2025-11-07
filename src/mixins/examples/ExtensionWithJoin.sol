// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "../ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "../ExtensionRewardMixin.sol";
import {ExtensionVerificationMixin} from "../ExtensionVerificationMixin.sol";
import {ExtensionScoreMixin} from "../ExtensionScoreMixin.sol";
import {ExtensionJoinMixin} from "../ExtensionJoinMixin.sol";

/// @title ExtensionWithJoin
/// @notice Example: Extension combining Score system with Join functionality
/// @dev This demonstrates how to compose mixins to create a complete extension
///
/// Mixin Composition:
/// - ExtensionCoreMixin: Core functionality (factory, initialization)
/// - ExtensionAccountMixin: Account management
/// - ExtensionRewardMixin: Reward distribution
/// - ExtensionVerificationMixin: Verification info management
/// - ExtensionScoreMixin: Score-based reward calculation
/// - ExtensionJoinMixin: Join/withdraw functionality
///
contract ExtensionWithJoin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_,
        uint256 minGovVotes_
    )
        ExtensionJoinMixin(
            factory_,
            joinTokenAddress_,
            waitingBlocks_,
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

