// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {PoolVerificationMixin} from "./PoolVerificationMixin.sol";
import {PoolDistrustVotingMixin} from "./PoolDistrustVotingMixin.sol";
import {ExtensionRewardMixin} from "../ExtensionRewardMixin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title PoolRewardMixin
/// @notice Mixin for pool reward distribution and calculation
/// @dev Handles complex reward formulas with penalties and service fees
///
/// **Reward Formula:**
/// ```
/// Pool Theory Reward = (Pool Participation / Total Participation) × Action Reward
/// Penalty Ratio = Distrust Votes / Total Verify Votes
/// Pool Actual Reward = Pool Theory Reward × (1 - Penalty Ratio)
/// Pool Service Fee = Pool Actual Reward × Service Fee Rate
/// Miner Reward = (Miner Score / Total Scores) × Pool Actual Reward × (1 - Service Fee Rate)
/// Burn Amount = Pool Theory Reward - Pool Actual Reward
/// ```
///
abstract contract PoolRewardMixin is
    PoolVerificationMixin,
    PoolDistrustVotingMixin,
    ExtensionRewardMixin
{
    // ============================================
    // ERRORS
    // ============================================
    error RewardAlreadyClaimed();
    error NoRewardAvailable();
    error InvalidServiceFeeRate();

    // ============================================
    // EVENTS
    // ============================================
    event MinerRewardClaimed(
        uint256 indexed poolId,
        uint256 indexed round,
        address indexed miner,
        uint256 reward
    );

    event PoolServiceFeeClaimed(
        uint256 indexed poolId,
        uint256 indexed round,
        address indexed poolOwner,
        uint256 serviceFee
    );

    event RewardBurned(
        uint256 indexed poolId,
        uint256 indexed round,
        uint256 burnedAmount
    );

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Reward parameters
    struct RewardParams {
        uint256 poolServiceFeeRate; // Service fee rate in basis points (10000 = 100%)
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Reward configuration parameters
    RewardParams public rewardParams;

    /// @notice Mapping: poolId => round => pool owner claimed service fee
    mapping(uint256 => mapping(uint256 => uint256))
        internal _poolClaimedServiceFee;

    /// @notice Mapping: poolId => round => burned amount
    mapping(uint256 => mapping(uint256 => uint256)) internal _poolBurnedAmount;

    /// @notice Mapping: round => whether reward has been prepared
    mapping(uint256 => bool) internal _rewardPrepared;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param params_ Reward parameters
    constructor(RewardParams memory params_) {
        if (params_.poolServiceFeeRate > 10000) {
            revert InvalidServiceFeeRate();
        }
        rewardParams = params_;
    }

    // ============================================
    // REWARD CALCULATION - POOL LEVEL
    // ============================================

    /// @notice Calculate pool's theory reward (before penalties)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Theory reward amount
    function calculatePoolTheoryReward(
        uint256 poolId,
        uint256 round
    ) public view returns (uint256) {
        // Get total action reward for this round
        uint256 totalActionReward = _getTotalActionReward(round);

        if (totalActionReward == 0) {
            return 0;
        }

        // Get pool participation from snapshot
        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        if (!snapshot.generated) {
            return 0;
        }

        // Get total participation across all pools
        uint256 totalParticipation = _getTotalPoolParticipation(round);

        if (totalParticipation == 0) {
            return 0;
        }

        // Theory Reward = (Pool Participation / Total Participation) × Total Reward
        return (snapshot.totalAmount * totalActionReward) / totalParticipation;
    }

    /// @notice Calculate pool's actual reward (after penalties)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Actual reward amount
    function calculatePoolActualReward(
        uint256 poolId,
        uint256 round
    ) public view returns (uint256) {
        uint256 theoryReward = calculatePoolTheoryReward(poolId, round);

        if (theoryReward == 0) {
            return 0;
        }

        // Get penalty ratio
        uint256 penaltyRatio = calculatePenaltyRatio(poolId, round);

        // Actual Reward = Theory Reward × (1 - Penalty Ratio)
        // penaltyRatio is in basis points (10000 = 100%)
        return (theoryReward * (10000 - penaltyRatio)) / 10000;
    }

    /// @notice Calculate pool service fee (pool owner's reward)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Service fee amount
    function calculatePoolServiceFee(
        uint256 poolId,
        uint256 round
    ) public view returns (uint256) {
        uint256 actualReward = calculatePoolActualReward(poolId, round);

        // Service Fee = Actual Reward × Service Fee Rate
        return (actualReward * rewardParams.poolServiceFeeRate) / 10000;
    }

    /// @notice Calculate burn amount (penalty portion)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Burn amount
    function calculateBurnAmount(
        uint256 poolId,
        uint256 round
    ) public view returns (uint256) {
        uint256 theoryReward = calculatePoolTheoryReward(poolId, round);
        uint256 actualReward = calculatePoolActualReward(poolId, round);

        // Burn = Theory - Actual
        return theoryReward - actualReward;
    }

    // ============================================
    // REWARD CALCULATION - MINER LEVEL
    // ============================================

    /// @notice Calculate miner's reward
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return Miner reward amount
    function calculateMinerReward(
        uint256 poolId,
        uint256 round,
        address miner
    ) public view returns (uint256) {
        // Get verification result
        VerificationResult storage verification = _verifications[poolId][round];

        if (!verification.submitted || verification.totalScores == 0) {
            return 0;
        }

        // Get miner's score directly from mapping (O(1))
        uint256 minerScore = verification.minerScores[miner];

        if (minerScore == 0) {
            return 0;
        }

        // Get pool actual reward
        uint256 actualReward = calculatePoolActualReward(poolId, round);

        // Calculate miner's portion (after service fee)
        uint256 minerPoolReward = (actualReward *
            (10000 - rewardParams.poolServiceFeeRate)) / 10000;

        // Miner Reward = (Miner Score / Total Scores) × Miner Pool Reward
        return (minerScore * minerPoolReward) / verification.totalScores;
    }

    // ============================================
    // REWARD PREPARATION
    // ============================================

    /// @dev Prepare action reward for a specific round if not already prepared
    /// @param round The round number to prepare reward for
    /// @dev Overrides ExtensionRewardMixin to use custom preparation logic for pools
    function _prepareRewardIfNeeded(uint256 round) internal override {
        // Check if already prepared
        if (_rewardPrepared[round]) {
            return;
        }

        // Mark as prepared
        _rewardPrepared[round] = true;

        // Call mint action reward (implemented by subclass)
        _mintActionRewardForRound(round);
    }

    // ============================================
    // REWARD CALCULATION (Override ExtensionRewardMixin)
    // ============================================

    /// @dev Calculate reward for an account in a specific round
    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual override returns (uint256 reward) {
        // Get historical pool ID using efficient binary search
        // This finds which pool the miner was in during that round
        uint256 poolId = getMinerPoolByRound(account, round);

        // If not in any pool during that round, no reward
        if (poolId == 0) {
            return 0;
        }

        // Calculate reward from the historical pool
        return calculateMinerReward(poolId, round, account);
    }

    /// @notice Claim pool service fee (pool owner only)
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return serviceFee Amount claimed
    function claimPoolServiceFee(
        uint256 poolId,
        uint256 round
    ) external onlyPoolOwner(poolId) returns (uint256 serviceFee) {
        // Check round is finished
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Auto-prepare reward if needed
        _prepareRewardIfNeeded(round);

        // Check not already claimed
        if (_poolClaimedServiceFee[poolId][round] > 0) {
            revert RewardAlreadyClaimed();
        }

        // Calculate service fee
        serviceFee = calculatePoolServiceFee(poolId, round);

        if (serviceFee == 0) {
            revert NoRewardAvailable();
        }

        // Mark as claimed
        _poolClaimedServiceFee[poolId][round] = serviceFee;

        // Transfer service fee
        IERC20(_token).transfer(msg.sender, serviceFee);

        // Handle burn (if any)
        _handleBurn(poolId, round);

        emit PoolServiceFeeClaimed(poolId, round, msg.sender, serviceFee);

        return serviceFee;
    }

    /// @dev Handle burning of penalty portion
    function _handleBurn(uint256 poolId, uint256 round) internal {
        uint256 burnAmount = calculateBurnAmount(poolId, round);

        if (burnAmount > 0 && _poolBurnedAmount[poolId][round] == 0) {
            _poolBurnedAmount[poolId][round] = burnAmount;

            // Burn tokens (transfer to address(0) or burn mechanism)
            // This depends on the token implementation
            // For now, we just track it

            emit RewardBurned(poolId, round, burnAmount);
        }
    }

    // ============================================
    // VIEW FUNCTIONS - REWARD STATUS
    // ============================================

    /// @notice Get miner's claimed reward
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return Claimed amount
    function getMinerClaimedReward(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (uint256) {
        poolId; // Silence unused variable warning
        return _claimedReward[round][miner];
    }

    /// @notice Get pool's claimed service fee
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Claimed service fee
    function getPoolClaimedServiceFee(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _poolClaimedServiceFee[poolId][round];
    }

    /// @notice Get pool's burned amount
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Burned amount
    function getPoolBurnedAmount(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _poolBurnedAmount[poolId][round];
    }

    /// @notice Check if miner has claimed reward
    /// @param poolId Pool ID (ignored, for backward compatibility)
    /// @param round Round number
    /// @param miner Miner address
    /// @return True if claimed
    function hasMinerClaimedReward(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (bool) {
        poolId; // Silence unused variable warning
        return _claimedReward[round][miner] > 0;
    }

    /// @notice Check if pool owner has claimed service fee
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return True if claimed
    function hasPoolClaimedServiceFee(
        uint256 poolId,
        uint256 round
    ) external view returns (bool) {
        return _poolClaimedServiceFee[poolId][round] > 0;
    }

    // ============================================
    // VIEW FUNCTIONS - REWARD INFO
    // ============================================

    /// @notice Get complete reward info for a pool
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return theoryReward Theory reward (before penalty)
    /// @return actualReward Actual reward (after penalty)
    /// @return serviceFee Pool service fee
    /// @return minerReward Total miner rewards
    /// @return burnAmount Burned amount
    /// @return penaltyRatio Penalty ratio in basis points
    function getPoolRewardInfo(
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            uint256 theoryReward,
            uint256 actualReward,
            uint256 serviceFee,
            uint256 minerReward,
            uint256 burnAmount,
            uint256 penaltyRatio
        )
    {
        theoryReward = calculatePoolTheoryReward(poolId, round);
        actualReward = calculatePoolActualReward(poolId, round);
        serviceFee = calculatePoolServiceFee(poolId, round);
        minerReward = actualReward - serviceFee;
        burnAmount = calculateBurnAmount(poolId, round);
        penaltyRatio = calculatePenaltyRatio(poolId, round);

        return (
            theoryReward,
            actualReward,
            serviceFee,
            minerReward,
            burnAmount,
            penaltyRatio
        );
    }

    /// @notice Get miner's reward info
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return pending Pending reward
    /// @return claimed Already claimed
    /// @return total Total (pending + claimed)
    function getMinerRewardInfo(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (uint256 pending, uint256 claimed, uint256 total) {
        total = calculateMinerReward(poolId, round, miner);
        claimed = _claimedReward[round][miner];
        pending = total > claimed ? total - claimed : 0;

        return (pending, claimed, total);
    }

    // ============================================
    // INTERNAL HOOKS (to be implemented by concrete contract)
    // ============================================

    /// @dev Mint action reward for a specific round
    /// @param round Round number
    /// @dev Called automatically during reward preparation
    /// @dev Implementation should call _mint.mintActionReward() to actually mint tokens
    function _mintActionRewardForRound(uint256 round) internal virtual;

    /// @dev Get total action reward for a round
    /// @param round Round number
    /// @return Total action reward
    function _getTotalActionReward(
        uint256 round
    ) internal view virtual returns (uint256);

    /// @dev Get total participation across all pools
    /// @param round Round number
    /// @return Total participation
    function _getTotalPoolParticipation(
        uint256 round
    ) internal view virtual returns (uint256);
}
