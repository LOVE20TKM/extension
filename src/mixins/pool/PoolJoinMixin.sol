// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {PoolCapacityMixin} from "./PoolCapacityMixin.sol";
import {ExtensionAccountMixin} from "../ExtensionAccountMixin.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title PoolJoinMixin
/// @notice Mixin for miner joining/exiting pools without lock period
/// @dev Handles immediate join/exit operations with no unlock period required
///
/// **Key Features:**
/// - Miners can join any active pool
/// - Only one pool per action per miner
/// - Immediate exit without lock period
/// - Automatic capacity checks
/// - Miner participation tracking
///
/// **Note:** This is for "join" mode participation (no lock period).
///          For staking with lock period, see PoolStakeMixin.
///
abstract contract PoolJoinMixin is PoolCapacityMixin, ExtensionAccountMixin {
    using ArrayUtils for uint256[];

    // ============================================
    // ERRORS
    // ============================================
    error AlreadyInPool();
    error NotInPool();
    error NotInThisPool();
    error AmountBelowMinimum();
    error AmountExceedsMinerCap();
    error PoolCapacityFull();
    error CannotJoinStoppedPool();

    // ============================================
    // EVENTS
    // ============================================
    event MinerJoinedPool(
        uint256 indexed poolId,
        address indexed miner,
        uint256 amount,
        uint256 joinedRound,
        string additionalInfo
    );

    event MinerExitedPool(
        uint256 indexed poolId,
        address indexed miner,
        uint256 amount,
        uint256 exitedRound
    );

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Miner participation information
    struct MinerParticipation {
        uint256 poolId; // Pool ID miner is participating in (0 = not participating)
        uint256 amount; // Amount of tokens participating
        uint256 joinedRound; // Round when miner joined
        string additionalInfo; // Additional information provided by miner
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Mapping from miner address to their participation info
    mapping(address => MinerParticipation) internal _minerParticipation;

    /// @notice Mapping from pool ID to list of miners
    mapping(uint256 => address[]) internal _poolMiners;

    /// @notice Mapping from pool ID to miner address to index in _poolMiners
    mapping(uint256 => mapping(address => uint256)) internal _minerIndexInPool;

    /// @notice Mapping: miner => round => poolId (pool history for efficient lookup)
    /// @dev Only records when miner joins/exits a pool (not every round)
    mapping(address => mapping(uint256 => uint256)) internal _minerPoolByRound;

    /// @notice Mapping: miner => rounds[] (rounds when miner changed pools)
    /// @dev Used for binary search to find historical pool efficiently
    mapping(address => uint256[]) internal _minerPoolChangeRounds;

    // ============================================
    // MINER OPERATIONS
    // ============================================

    /// @notice Join a mining pool
    /// @param poolId Pool ID to join
    /// @param amount Amount of tokens to participate with
    /// @param additionalInfo Additional information required by pool
    function joinPool(
        uint256 poolId,
        uint256 amount,
        string memory additionalInfo
    ) public virtual poolExists(poolId) poolActive(poolId) {
        // Hook for snapshot mechanism - BEFORE any state change
        _beforeMinerJoins(poolId, msg.sender);

        // Check miner is not already in a pool
        MinerParticipation storage participation = _minerParticipation[
            msg.sender
        ];
        if (participation.poolId != 0) {
            revert AlreadyInPool();
        }

        // Validate amount
        if (amount == 0) {
            revert AmountBelowMinimum();
        }

        PoolInfo storage pool = _pools[poolId];

        // Check minimum amount requirement
        if (amount < pool.minMinerAmount) {
            revert AmountBelowMinimum();
        }

        // Check miner cap
        uint256 minerMaxAmount = calculateMinerMaxAmount();
        if (amount > minerMaxAmount) {
            revert AmountExceedsMinerCap();
        }

        // Check pool capacity
        if (!checkCapacityAvailable(poolId, amount)) {
            revert PoolCapacityFull();
        }

        // Transfer tokens
        _token.transferFrom(msg.sender, address(this), amount);

        // Update miner participation
        uint256 currentRound = _join.currentRound();
        participation.poolId = poolId;
        participation.amount = amount;
        participation.joinedRound = currentRound;
        participation.additionalInfo = additionalInfo;

        // Record pool change history (only when pool changes, not every round)
        uint256[] storage changeRounds = _minerPoolChangeRounds[msg.sender];
        if (
            changeRounds.length == 0 ||
            changeRounds[changeRounds.length - 1] != currentRound
        ) {
            changeRounds.push(currentRound);
        }
        _minerPoolByRound[msg.sender][currentRound] = poolId;

        // Update pool
        pool.totalParticipation += amount;

        // Add miner to pool's miner list
        uint256 minerIndex = _poolMiners[poolId].length;
        _poolMiners[poolId].push(msg.sender);
        _minerIndexInPool[poolId][msg.sender] = minerIndex;

        // Add to accounts tracking
        _addAccount(msg.sender);

        emit MinerJoinedPool(
            poolId,
            msg.sender,
            amount,
            currentRound,
            additionalInfo
        );
    }

    /// @notice Exit from mining pool (immediate exit, no lock period)
    /// @param poolId Pool ID to exit from
    function exitPool(uint256 poolId) public virtual poolExists(poolId) {
        // Hook for snapshot mechanism - BEFORE any state change
        _beforeMinerExits(poolId, msg.sender);

        MinerParticipation storage participation = _minerParticipation[
            msg.sender
        ];

        // Check miner is in a pool
        if (participation.poolId == 0) {
            revert NotInPool();
        }

        // Check miner is in the specified pool
        if (participation.poolId != poolId) {
            revert NotInThisPool();
        }

        uint256 amount = participation.amount;
        PoolInfo storage pool = _pools[poolId];

        // Record pool change history (exit = poolId becomes 0)
        uint256 currentRound = _join.currentRound();
        uint256[] storage changeRounds = _minerPoolChangeRounds[msg.sender];
        if (
            changeRounds.length == 0 ||
            changeRounds[changeRounds.length - 1] != currentRound
        ) {
            changeRounds.push(currentRound);
        }
        _minerPoolByRound[msg.sender][currentRound] = 0; // 0 means not in any pool

        // Update pool
        pool.totalParticipation -= amount;

        // Remove miner from pool's miner list
        _removeMinerFromPool(poolId, msg.sender);

        // Clear miner participation
        delete _minerParticipation[msg.sender];

        // Remove from accounts tracking
        _removeAccount(msg.sender);

        // Return tokens immediately (no lock period)
        _token.transfer(msg.sender, amount);

        emit MinerExitedPool(poolId, msg.sender, amount, currentRound);
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Remove miner from pool's miner list
    function _removeMinerFromPool(uint256 poolId, address miner) internal {
        uint256 minerIndex = _minerIndexInPool[poolId][miner];
        address[] storage miners = _poolMiners[poolId];
        uint256 lastIndex = miners.length - 1;

        if (minerIndex != lastIndex) {
            // Move last miner to the removed position
            address lastMiner = miners[lastIndex];
            miners[minerIndex] = lastMiner;
            _minerIndexInPool[poolId][lastMiner] = minerIndex;
        }

        // Remove last element
        miners.pop();
        delete _minerIndexInPool[poolId][miner];
    }

    /// @dev Hook called BEFORE miner joins (for snapshot mechanism)
    /// @dev Subclasses should override to capture state BEFORE the join
    function _beforeMinerJoins(
        uint256 poolId,
        address miner
    ) internal virtual {}

    /// @dev Hook called BEFORE miner exits (for snapshot mechanism)
    /// @dev Subclasses should override to capture state BEFORE the exit
    function _beforeMinerExits(
        uint256 poolId,
        address miner
    ) internal virtual {}

    // ============================================
    // VIEW FUNCTIONS - MINER INFO
    // ============================================

    /// @notice Get miner's participation information
    /// @param miner Miner address
    /// @return Miner participation struct
    function getMinerParticipation(
        address miner
    ) external view returns (MinerParticipation memory) {
        return _minerParticipation[miner];
    }

    /// @notice Check if miner is in a pool
    /// @param miner Miner address
    /// @return True if miner is participating in any pool
    function isMinerInAnyPool(address miner) external view returns (bool) {
        return _minerParticipation[miner].poolId != 0;
    }

    /// @notice Check if miner is in a specific pool
    /// @param miner Miner address
    /// @param poolId Pool ID
    /// @return True if miner is in the specified pool
    function isMinerInPool(
        address miner,
        uint256 poolId
    ) external view returns (bool) {
        return _minerParticipation[miner].poolId == poolId;
    }

    /// @notice Get pool that miner is participating in
    /// @param miner Miner address
    /// @return Pool ID (0 if not in any pool)
    function getMinerPoolId(address miner) external view returns (uint256) {
        return _minerParticipation[miner].poolId;
    }

    /// @notice Get miner's participation amount
    /// @param miner Miner address
    /// @return Amount of tokens miner is participating with
    function getMinerAmount(address miner) external view returns (uint256) {
        return _minerParticipation[miner].amount;
    }

    // ============================================
    // VIEW FUNCTIONS - POOL MINERS
    // ============================================

    /// @notice Get all miners in a pool
    /// @param poolId Pool ID
    /// @return Array of miner addresses
    function getPoolMiners(
        uint256 poolId
    ) external view returns (address[] memory) {
        return _poolMiners[poolId];
    }

    /// @notice Get number of miners in a pool
    /// @param poolId Pool ID
    /// @return Number of miners
    function getPoolMinerCount(uint256 poolId) external view returns (uint256) {
        return _poolMiners[poolId].length;
    }

    /// @notice Get miner at specific index in pool
    /// @param poolId Pool ID
    /// @param index Index
    /// @return Miner address
    function getPoolMinerAtIndex(
        uint256 poolId,
        uint256 index
    ) external view returns (address) {
        return _poolMiners[poolId][index];
    }

    /// @notice Get total participation amount in pool
    /// @param poolId Pool ID
    /// @return Total amount
    function getPoolTotalParticipation(
        uint256 poolId
    ) external view returns (uint256) {
        return _pools[poolId].totalParticipation;
    }

    // ============================================
    // VIEW FUNCTIONS - VALIDATION
    // ============================================

    /// @notice Check if miner can join a pool
    /// @param miner Miner address
    /// @param poolId Pool ID
    /// @param amount Amount to participate with
    /// @return canJoin True if miner can join
    /// @return reason Reason if cannot join (empty if can join)
    function canMinerJoinPool(
        address miner,
        uint256 poolId,
        uint256 amount
    ) external view returns (bool canJoin, string memory reason) {
        // Check if pool exists
        if (_pools[poolId].owner == address(0)) {
            return (false, "Pool does not exist");
        }

        // Check if pool is stopped
        if (_pools[poolId].isStopped) {
            return (false, "Pool is stopped");
        }

        // Check if miner is already in a pool
        if (_minerParticipation[miner].poolId != 0) {
            return (false, "Already in a pool");
        }

        // Check minimum amount
        if (amount < _pools[poolId].minMinerAmount) {
            return (false, "Amount below minimum");
        }

        // Check miner cap
        uint256 minerMaxAmount = calculateMinerMaxAmount();
        if (amount > minerMaxAmount) {
            return (false, "Amount exceeds miner cap");
        }

        // Check pool capacity
        if (!checkCapacityAvailable(poolId, amount)) {
            return (false, "Pool capacity full");
        }

        return (true, "");
    }

    // ============================================
    // HISTORICAL POOL LOOKUP
    // ============================================

    /// @notice Get which pool a miner was in during a specific round (efficient binary search)
    /// @param miner Miner address
    /// @param round Round number
    /// @return poolId Pool ID (0 if miner was not in any pool)
    /// @dev If miner joined/exited in the queried round, returns the PREVIOUS pool
    ///      (because rewards for that round are based on the pool they were in at round start)
    function getMinerPoolByRound(
        address miner,
        uint256 round
    ) public view returns (uint256 poolId) {
        uint256[] storage changeRounds = _minerPoolChangeRounds[miner];

        if (changeRounds.length == 0) {
            return 0;
        }

        // Use binary search to find the nearest round <= target round
        (bool found, uint256 nearestRound) = changeRounds
            .findLeftNearestOrEqualValue(round);

        if (!found) {
            return 0;
        }

        // Critical logic: If miner joined/exited in THIS round,
        // the reward for THIS round should be based on PREVIOUS pool
        if (nearestRound == round) {
            // This is the round when miner changed pools
            // Find the previous change point by searching for round - 1
            if (round == 0) {
                return 0;
            }

            (bool foundPrev, uint256 prevRound) = changeRounds
                .findLeftNearestOrEqualValue(round - 1);

            if (!foundPrev) {
                // No previous pool
                return 0;
            }

            // Return the pool from previous change point
            return _minerPoolByRound[miner][prevRound];
        }

        // Normal case: miner was already in this pool during the queried round
        return _minerPoolByRound[miner][nearestRound];
    }
}
