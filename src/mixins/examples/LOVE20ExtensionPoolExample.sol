// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "../ExtensionAccountMixin.sol";
import {ExtensionRewardMixin} from "../ExtensionRewardMixin.sol";
import {ExtensionVerificationMixin} from "../ExtensionVerificationMixin.sol";

import {PoolManagerMixin} from "../pool/PoolManagerMixin.sol";
import {PoolCapacityMixin} from "../pool/PoolCapacityMixin.sol";
import {PoolJoinMixin} from "../pool/PoolJoinMixin.sol";
import {PoolSnapshotMixin} from "../pool/PoolSnapshotMixin.sol";
import {PoolVerificationMixin} from "../pool/PoolVerificationMixin.sol";
import {PoolDistrustVotingMixin} from "../pool/PoolDistrustVotingMixin.sol";
import {PoolRewardMixin} from "../pool/PoolRewardMixin.sol";
import {PoolQueryMixin} from "../pool/PoolQueryMixin.sol";

import {ILOVE20Extension} from "../../interface/ILOVE20Extension.sol";

/// @title LOVE20ExtensionPoolExample
/// @notice Example implementation of pool mining extension using Mixin architecture
/// @dev Combines 8 Pool Mixins + 4 Base Mixins to create a complete pool mining system
///
/// **Architecture:**
/// ```
/// ExtensionCoreMixin              (Factory, Token, Action, Center)
///     ↓
/// PoolManagerMixin                (Pool Creation, Management)
///     ↓
/// PoolCapacityMixin               (Capacity Calculation, Limits)
///     ↓
/// PoolJoinMixin                   (Miner Join/Exit, No Lock Period) + ExtensionAccountMixin
///     ↓
/// PoolSnapshotMixin               (Auto Snapshot)
///     ↓
/// PoolVerificationMixin           (Verification Submission)
///     ↓
///     ├─→ PoolDistrustVotingMixin (Pool Governance Voting)
///     │       ↓
///     └───────→ PoolRewardMixin   (Reward Distribution) + ExtensionRewardMixin
///                 ↓
///             PoolQueryMixin      (Query Helpers)
/// ```
///
contract LOVE20ExtensionPoolExample is
    // Base mixins from extension library
    ExtensionVerificationMixin, // Verification info management
    // Pool-specific mixins (in dependency order)
    PoolQueryMixin // Includes all below via inheritance
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ Factory contract address
    /// @param capacityParams_ Capacity calculation parameters
    /// @param rewardParams_ Reward distribution parameters
    constructor(
        address factory_,
        PoolCapacityMixin.CapacityParams memory capacityParams_,
        PoolRewardMixin.RewardParams memory rewardParams_
    )
        ExtensionCoreMixin(factory_)
        PoolCapacityMixin(capacityParams_)
        PoolRewardMixin(rewardParams_)
    {}

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @notice Initialize the extension
    /// @param tokenAddress_ Token address
    /// @param actionId_ Action ID
    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) public override(ExtensionCoreMixin) onlyCenter {
        ExtensionCoreMixin.initialize(tokenAddress_, actionId_);
    }

    // ============================================
    // REWARD INTERFACE IMPLEMENTATION
    // ============================================

    /// @notice Calculate reward for an account in a specific round
    /// @dev Required by ExtensionRewardMixin
    /// @param round The round number
    /// @param account The account address
    /// @return reward The amount of reward
    /// @return isMinted Whether the reward has been minted
    function rewardByAccount(
        uint256 round,
        address account
    ) public view override returns (uint256 reward, bool isMinted) {
        // Get miner's participation info
        MinerParticipation memory participation = _minerParticipation[account];

        if (participation.poolId == 0) {
            return (0, false);
        }

        // Calculate reward from pool
        reward = calculateMinerReward(participation.poolId, round, account);
        isMinted = _claimedReward[round][account] > 0;

        return (reward, isMinted);
    }

    // ============================================
    // DISTRUST VOTING HOOKS IMPLEMENTATION
    // ============================================

    /// @dev Get total verification votes for the action
    /// @param round Round number
    /// @return Total verify votes
    function _getTotalVerifyVotesImpl(
        uint256 round
    ) internal view override returns (uint256) {
        // Directly query total verification scores for this extension contract
        // Much more efficient than looping through all pools
        return
            _verify.scoreByActionIdByAccount(
                tokenAddress,
                round,
                actionId,
                address(this) // Extension contract itself is the account being verified
            );
    }

    /// @dev Check if voter completed verification
    /// @param voter Voter address
    /// @param round Round number
    /// @return True if completed
    function _hasCompletedVerification(
        address voter,
        uint256 round
    ) internal view override returns (bool) {
        // Check if voter verified this extension contract (whitelist address)
        // Query verification score for the extension contract itself as the account
        uint256 verificationScore = _verify.scoreByVerifierByActionIdByAccount(
            tokenAddress,
            round,
            voter,
            actionId,
            address(this) // Extension contract itself is the account being verified
        );
        return verificationScore > 0;
    }

    /// @dev Get voter's verification votes
    /// @param voter Voter address
    /// @param round Round number
    /// @return Verification votes
    function _getVoterVerificationVotes(
        address voter,
        uint256 round
    ) internal view override returns (uint256) {
        // Get voter's verification votes for this extension contract
        // This represents non-abstain verification tickets for this specific extension
        return
            _verify.scoreByVerifierByActionIdByAccount(
                tokenAddress,
                round,
                voter,
                actionId,
                address(this) // Extension contract itself is the account being verified
            );
    }

    // ============================================
    // REWARD CALCULATION HOOKS IMPLEMENTATION
    // ============================================

    /// @dev Mint action reward for a specific round
    /// @param round Round number
    function _mintActionRewardForRound(uint256 round) internal override {
        // Call LOVE20Mint to actually mint tokens to this contract
        _mint.mintActionReward(tokenAddress, round, actionId);
    }

    /// @dev Get total action reward for a round
    /// @param round Round number
    /// @return Total action reward
    function _getTotalActionReward(
        uint256 round
    ) internal view override returns (uint256) {
        // Get total action reward for this round
        return _mint.actionReward(tokenAddress, round);
    }

    /// @dev Get total participation across all pools
    /// @param round Round number
    /// @return Total participation
    function _getTotalPoolParticipation(
        uint256 round
    ) internal view override returns (uint256) {
        // Directly return accumulated total participation (O(1) query)
        // This value is accumulated in PoolSnapshotMixin when each snapshot is generated
        return _totalParticipationByRound[round];
    }

    // ============================================
    // ADDITIONAL HELPER FUNCTIONS
    // ============================================

    /// @notice Get version information
    /// @return Version string
    function version() external pure returns (string memory) {
        return "LOVE20ExtensionPool v1.0.0";
    }
}
