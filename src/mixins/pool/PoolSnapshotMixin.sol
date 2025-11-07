// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {PoolJoinMixin} from "./PoolJoinMixin.sol";

/// @title PoolSnapshotMixin
/// @notice Mixin for automatic snapshot mechanism
/// @dev Captures pool state at key moments for verification basis
///
/// **Snapshot Triggers:**
/// 1. Miner joins pool
/// 2. Miner exits pool
/// 3. Pool owner/verifier submits verification
///
/// **Key Feature:** Only ONE snapshot per pool per round
///
abstract contract PoolSnapshotMixin is PoolJoinMixin {
    // ============================================
    // EVENTS
    // ============================================
    event SnapshotGenerated(
        uint256 indexed poolId,
        uint256 indexed round,
        uint256 minerCount,
        uint256 totalAmount,
        uint256 timestamp
    );

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Snapshot data structure
    struct PoolSnapshot {
        uint256 round; // Snapshot round
        uint256 poolId; // Pool ID
        address[] miners; // Snapshot of miners
        uint256[] amounts; // Snapshot of amounts
        uint256 totalAmount; // Total participation amount
        uint256 timestamp; // Block timestamp when generated
        bool generated; // Whether snapshot was generated
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Mapping: poolId => round => snapshot
    mapping(uint256 => mapping(uint256 => PoolSnapshot)) internal _snapshots;

    /// @notice Mapping: round => total participation amount across all pools
    /// @dev Accumulated when generating snapshots for efficient query
    mapping(uint256 => uint256) internal _totalParticipationByRound;

    // ============================================
    // SNAPSHOT GENERATION
    // ============================================

    /// @notice Trigger snapshot if needed (internal, auto-called)
    /// @param poolId Pool ID
    /// @dev Called automatically when:
    ///      - Miner joins
    ///      - Miner exits
    ///      - Verification submitted
    function _triggerSnapshotIfNeeded(uint256 poolId) internal {
        uint256 currentRound = _join.currentRound();

        // Skip round 0 (no verification in round 0)
        if (currentRound == 0) {
            return;
        }

        // Check if snapshot already generated for this round
        if (_snapshots[poolId][currentRound].generated) {
            return;
        }

        // Generate snapshot
        _generateSnapshot(poolId, currentRound);
    }

    /// @dev Actually generate the snapshot
    function _generateSnapshot(uint256 poolId, uint256 round) internal {
        address[] memory miners = _poolMiners[poolId];
        uint256 minerCount = miners.length;

        // Allocate arrays
        uint256[] memory amounts = new uint256[](minerCount);
        uint256 totalAmount = 0;

        // Copy miner data
        for (uint256 i = 0; i < minerCount; i++) {
            address miner = miners[i];
            uint256 amount = _minerParticipation[miner].amount;
            amounts[i] = amount;
            totalAmount += amount;
        }

        // Store snapshot
        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        snapshot.round = round;
        snapshot.poolId = poolId;
        snapshot.miners = miners;
        snapshot.amounts = amounts;
        snapshot.totalAmount = totalAmount;
        snapshot.timestamp = block.timestamp;
        snapshot.generated = true;

        // Accumulate total participation for this round (O(1) query optimization)
        _totalParticipationByRound[round] += totalAmount;

        emit SnapshotGenerated(
            poolId,
            round,
            minerCount,
            totalAmount,
            block.timestamp
        );
    }

    // ============================================
    // PARTICIPATION HOOKS IMPLEMENTATION
    // ============================================

    /// @inheritdoc PoolJoinMixin
    /// @dev Generate snapshot BEFORE miner joins to capture the pool state without the new miner
    function _beforeMinerJoins(
        uint256 poolId,
        address /* miner */
    ) internal virtual override {
        _triggerSnapshotIfNeeded(poolId);
    }

    /// @inheritdoc PoolJoinMixin
    /// @dev Generate snapshot BEFORE miner exits to capture the pool state with the exiting miner
    function _beforeMinerExits(
        uint256 poolId,
        address /* miner */
    ) internal virtual override {
        _triggerSnapshotIfNeeded(poolId);
    }

    // ============================================
    // VIEW FUNCTIONS - SNAPSHOT DATA
    // ============================================

    /// @notice Get snapshot for a pool in a specific round
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Snapshot data
    function getSnapshot(
        uint256 poolId,
        uint256 round
    ) external view returns (PoolSnapshot memory) {
        return _snapshots[poolId][round];
    }

    /// @notice Check if snapshot was generated
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return True if snapshot exists
    function isSnapshotGenerated(
        uint256 poolId,
        uint256 round
    ) external view returns (bool) {
        return _snapshots[poolId][round].generated;
    }

    /// @notice Get miner's amount in snapshot
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return Amount in snapshot (0 if not found)
    function getSnapshotMinerAmount(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (uint256) {
        PoolSnapshot storage snapshot = _snapshots[poolId][round];

        if (!snapshot.generated) {
            return 0;
        }

        // Search for miner in snapshot
        for (uint256 i = 0; i < snapshot.miners.length; i++) {
            if (snapshot.miners[i] == miner) {
                return snapshot.amounts[i];
            }
        }

        return 0;
    }

    /// @notice Get snapshot miner count
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Number of miners in snapshot
    function getSnapshotMinerCount(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _snapshots[poolId][round].miners.length;
    }

    /// @notice Get snapshot total amount
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Total amount in snapshot
    function getSnapshotTotalAmount(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256) {
        return _snapshots[poolId][round].totalAmount;
    }

    /// @notice Get snapshot miners array
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Array of miner addresses
    function getSnapshotMiners(
        uint256 poolId,
        uint256 round
    ) external view returns (address[] memory) {
        return _snapshots[poolId][round].miners;
    }

    /// @notice Get snapshot amounts array
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return Array of amounts
    function getSnapshotAmounts(
        uint256 poolId,
        uint256 round
    ) external view returns (uint256[] memory) {
        return _snapshots[poolId][round].amounts;
    }

    // ============================================
    // VIEW FUNCTIONS - SNAPSHOT QUERIES
    // ============================================

    /// @notice Get snapshot info summary
    /// @param poolId Pool ID
    /// @param round Round number
    /// @return generated Whether snapshot was generated
    /// @return minerCount Number of miners
    /// @return totalAmount Total participation amount
    /// @return timestamp When snapshot was created
    function getSnapshotInfo(
        uint256 poolId,
        uint256 round
    )
        external
        view
        returns (
            bool generated,
            uint256 minerCount,
            uint256 totalAmount,
            uint256 timestamp
        )
    {
        PoolSnapshot storage snapshot = _snapshots[poolId][round];
        return (
            snapshot.generated,
            snapshot.miners.length,
            snapshot.totalAmount,
            snapshot.timestamp
        );
    }

    /// @notice Check if miner was in snapshot
    /// @param poolId Pool ID
    /// @param round Round number
    /// @param miner Miner address
    /// @return True if miner was in snapshot
    function wasMinerInSnapshot(
        uint256 poolId,
        uint256 round,
        address miner
    ) external view returns (bool) {
        PoolSnapshot storage snapshot = _snapshots[poolId][round];

        if (!snapshot.generated) {
            return false;
        }

        for (uint256 i = 0; i < snapshot.miners.length; i++) {
            if (snapshot.miners[i] == miner) {
                return true;
            }
        }

        return false;
    }
}
