// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {PoolRewardMixin} from "./PoolRewardMixin.sol";

/// @title PoolQueryMixin
/// @notice Helper mixin for convenient query operations
/// @dev Provides aggregated data views and statistics
///
abstract contract PoolQueryMixin is PoolRewardMixin {
    // ============================================
    // POOL OVERVIEW QUERIES
    // ============================================

    /// @notice Get complete pool overview
    /// @param poolId Pool ID
    /// @return info Pool information
    /// @return minerCount Number of miners
    /// @return currentRound Current round
    /// @return isActive Whether pool is active
    function getPoolOverview(
        uint256 poolId
    )
        external
        view
        returns (
            PoolInfo memory info,
            uint256 minerCount,
            uint256 currentRound,
            bool isActive
        )
    {
        info = _pools[poolId];
        minerCount = _poolMiners[poolId].length;
        currentRound = _join.currentRound();
        isActive = !info.isStopped;

        return (info, minerCount, currentRound, isActive);
    }

    /// @notice Get pool statistics for a specific round
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return snapshotGenerated Whether snapshot was generated
    /// @return verificationSubmitted Whether verification was submitted
    /// @return minerCount Number of miners in snapshot
    /// @return totalParticipation Total participation amount
    /// @return totalScores Total verification scores
    /// @return distrustVotes Total distrust votes
    function getPoolRoundStats(
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            bool snapshotGenerated,
            bool verificationSubmitted,
            uint256 minerCount,
            uint256 totalParticipation,
            uint256 totalScores,
            uint256 distrustVotes
        )
    {
        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        VerificationResult storage verification = _verifications[poolId][round];

        snapshotGenerated = snapshot.generated;
        verificationSubmitted = verification.submitted;
        minerCount = snapshot.miners.length;
        totalParticipation = snapshot.totalAmount;
        totalScores = verification.totalScores;
        distrustVotes = _distrustVotes[poolId][round].totalVotes;

        return (
            snapshotGenerated,
            verificationSubmitted,
            minerCount,
            totalParticipation,
            totalScores,
            distrustVotes
        );
    }

    // ============================================
    // MINER OVERVIEW QUERIES
    // ============================================

    /// @notice Get complete miner overview
    /// @param miner Miner address
    /// @return participation Miner's participation info
    /// @return poolInfo Pool information (if in a pool)
    /// @return totalRewardClaimed Total rewards claimed
    function getMinerOverview(
        address miner
    )
        external
        view
        returns (
            MinerParticipation memory participation,
            PoolInfo memory poolInfo,
            uint256 totalRewardClaimed
        )
    {
        participation = _minerParticipation[miner];

        if (participation.poolId != 0) {
            poolInfo = _pools[participation.poolId];
        }

        // Calculate total rewards claimed (would need to iterate rounds)
        totalRewardClaimed = 0; // Simplified, full implementation would sum all rounds

        return (participation, poolInfo, totalRewardClaimed);
    }

    /// @notice Get miner's status in a pool for a specific round
    /// @param miner Miner address
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return inSnapshot Whether miner was in snapshot
    /// @return verified Whether miner was verified
    /// @return snapshotAmount Amount in snapshot
    /// @return verificationScore Verification score received
    /// @return pendingReward Pending reward
    /// @return claimedReward Already claimed reward
    function getMinerRoundStatus(
        address miner,
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            bool inSnapshot,
            bool verified,
            uint256 snapshotAmount,
            uint256 verificationScore,
            uint256 pendingReward,
            uint256 claimedReward
        )
    {
        // Check snapshot
        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        for (uint256 i = 0; i < snapshot.miners.length; i++) {
            if (snapshot.miners[i] == miner) {
                inSnapshot = true;
                snapshotAmount = snapshot.amounts[i];
                break;
            }
        }

        // Check verification (O(1) lookup from mapping)
        VerificationResult storage verification = _verifications[poolId][round];
        if (verification.submitted) {
            verificationScore = verification.minerScores[miner];
            verified = verificationScore > 0;
        }

        // Get rewards
        uint256 totalReward = calculateMinerReward(poolId, round, miner);
        claimedReward = _claimedReward[round][miner];
        pendingReward = totalReward > claimedReward
            ? totalReward - claimedReward
            : 0;

        return (
            inSnapshot,
            verified,
            snapshotAmount,
            verificationScore,
            pendingReward,
            claimedReward
        );
    }

    // ============================================
    // LIST QUERIES WITH PAGINATION
    // ============================================

    /// @notice Get pools with pagination
    /// @param offset Starting index
    /// @param limit Maximum number of results
    /// @return poolIds Array of pool IDs
    /// @return total Total number of pools
    function getPools(
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory poolIds, uint256 total) {
        total = _allPoolIds.length;

        if (offset >= total) {
            return (new uint256[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 resultLength = end - offset;
        poolIds = new uint256[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            poolIds[i] = _allPoolIds[offset + i];
        }

        return (poolIds, total);
    }

    /// @notice Get active pools (not stopped)
    /// @return poolIds Array of active pool IDs
    function getActivePools() external view returns (uint256[] memory poolIds) {
        // Count active pools
        uint256 activeCount = 0;
        for (uint256 i = 0; i < _allPoolIds.length; i++) {
            if (!_pools[_allPoolIds[i]].isStopped) {
                activeCount++;
            }
        }

        // Collect active pools
        poolIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < _allPoolIds.length; i++) {
            if (!_pools[_allPoolIds[i]].isStopped) {
                poolIds[index++] = _allPoolIds[i];
            }
        }

        return poolIds;
    }

    /// @notice Get pools by owner
    /// @param owner Owner address
    /// @return poolIds Array of pool IDs owned by address
    function getPoolsByOwner(
        address owner
    ) external view override returns (uint256[] memory poolIds) {
        return _poolsByOwner[owner];
    }

    // ============================================
    // STATISTICS QUERIES
    // ============================================

    /// @notice Get global pool statistics
    /// @return totalPools Total number of pools
    /// @return activePools Number of active pools
    /// @return stoppedPools Number of stopped pools
    /// @return totalMiners Total number of miners across all pools
    function getGlobalStats()
        external
        view
        returns (
            uint256 totalPools,
            uint256 activePools,
            uint256 stoppedPools,
            uint256 totalMiners
        )
    {
        totalPools = _allPoolIds.length;

        for (uint256 i = 0; i < _allPoolIds.length; i++) {
            if (_pools[_allPoolIds[i]].isStopped) {
                stoppedPools++;
            } else {
                activePools++;
                totalMiners += _poolMiners[_allPoolIds[i]].length;
            }
        }

        return (totalPools, activePools, stoppedPools, totalMiners);
    }

    /// @notice Get pool capacity utilization
    /// @param poolId Pool ID
    /// @return capacity Total capacity
    /// @return used Used capacity
    /// @return utilization Utilization rate in basis points (10000 = 100%)
    function getPoolUtilization(
        uint256 poolId
    )
        external
        view
        returns (uint256 capacity, uint256 used, uint256 utilization)
    {
        PoolInfo storage pool = _pools[poolId];
        capacity = pool.capacity;
        used = pool.totalParticipation;

        if (capacity > 0) {
            utilization = (used * 10000) / capacity;
        } else {
            utilization = 0;
        }

        return (capacity, used, utilization);
    }

    /// @notice Get top pools by participation
    /// @param limit Number of pools to return
    /// @return poolIds Array of pool IDs sorted by participation
    /// @return amounts Array of participation amounts
    function getTopPoolsByParticipation(
        uint256 limit
    )
        external
        view
        returns (uint256[] memory poolIds, uint256[] memory amounts)
    {
        uint256 poolCount = _allPoolIds.length;
        if (poolCount == 0) {
            return (new uint256[](0), new uint256[](0));
        }

        // Create arrays for all pools
        uint256[] memory allPoolIds = new uint256[](poolCount);
        uint256[] memory allAmounts = new uint256[](poolCount);

        for (uint256 i = 0; i < poolCount; i++) {
            allPoolIds[i] = _allPoolIds[i];
            allAmounts[i] = _pools[_allPoolIds[i]].totalParticipation;
        }

        // Simple bubble sort (for small arrays, can optimize for larger sets)
        for (uint256 i = 0; i < poolCount; i++) {
            for (uint256 j = i + 1; j < poolCount; j++) {
                if (allAmounts[j] > allAmounts[i]) {
                    // Swap
                    uint256 tempId = allPoolIds[i];
                    uint256 tempAmount = allAmounts[i];
                    allPoolIds[i] = allPoolIds[j];
                    allAmounts[i] = allAmounts[j];
                    allPoolIds[j] = tempId;
                    allAmounts[j] = tempAmount;
                }
            }
        }

        // Return top N
        uint256 resultLength = limit > poolCount ? poolCount : limit;
        poolIds = new uint256[](resultLength);
        amounts = new uint256[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            poolIds[i] = allPoolIds[i];
            amounts[i] = allAmounts[i];
        }

        return (poolIds, amounts);
    }

    // ============================================
    // BATCH QUERIES
    // ============================================

    /// @notice Get info for multiple pools at once
    /// @param poolIds Array of pool IDs
    /// @return infos Array of pool information
    function getMultiplePoolInfo(
        uint256[] memory poolIds
    ) external view returns (PoolInfo[] memory infos) {
        infos = new PoolInfo[](poolIds.length);

        for (uint256 i = 0; i < poolIds.length; i++) {
            infos[i] = _pools[poolIds[i]];
        }

        return infos;
    }

    /// @notice Check multiple miners' participation status
    /// @param miners Array of miner addresses
    /// @return poolIds Array of pool IDs (0 if not participating)
    /// @return amounts Array of participation amounts
    function getMultipleMinerStatus(
        address[] memory miners
    )
        external
        view
        returns (uint256[] memory poolIds, uint256[] memory amounts)
    {
        poolIds = new uint256[](miners.length);
        amounts = new uint256[](miners.length);

        for (uint256 i = 0; i < miners.length; i++) {
            MinerParticipation storage participation = _minerParticipation[
                miners[i]
            ];
            poolIds[i] = participation.poolId;
            amounts[i] = participation.amount;
        }

        return (poolIds, amounts);
    }
}
