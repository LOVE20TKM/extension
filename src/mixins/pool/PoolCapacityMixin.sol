// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {PoolManagerMixin} from "./PoolManagerMixin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title PoolCapacityMixin
/// @notice Mixin for pool capacity management and validation
/// @dev Handles capacity calculations, governance ratio checks, and limits
///
/// **Capacity Formula:**
/// - Pool Capacity = Staked Amount × Stake Multiplier
/// - Owner Max Capacity = Total Minted × Owner Gov Ratio × Capacity Multiplier
/// - Miner Max Amount = Total Minted / Miner Cap Multiplier
///
abstract contract PoolCapacityMixin is PoolManagerMixin {
    // ============================================
    // ERRORS
    // ============================================
    error InsufficientGovRatio();
    error CapacityExceeded();
    error OwnerCapacityExceeded();
    error InvalidCapacityParams();

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Capacity parameters structure
    struct CapacityParams {
        uint256 minGovRatio; // Minimum governance ratio (in basis points, 10000 = 100%)
        uint256 capacityMultiplier; // Capacity multiplier
        uint256 stakeMultiplier; // Stake multiplier (capacity = stake × this)
        uint256 minerCapMultiplier; // Miner max amount divisor
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Capacity configuration parameters
    CapacityParams public capacityParams;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param params_ Capacity parameters
    constructor(CapacityParams memory params_) PoolManagerMixin() {
        if (params_.minGovRatio == 0 || params_.minGovRatio > 10000) {
            revert InvalidCapacityParams();
        }
        if (params_.capacityMultiplier == 0) {
            revert InvalidCapacityParams();
        }
        if (params_.stakeMultiplier == 0) {
            revert InvalidCapacityParams();
        }
        if (params_.minerCapMultiplier == 0) {
            revert InvalidCapacityParams();
        }

        capacityParams = params_;
    }

    // ============================================
    // CAPACITY CALCULATION
    // ============================================

    /// @notice Calculate pool capacity based on staked amount
    /// @param stakedAmount Amount of tokens staked
    /// @return Pool capacity
    function calculatePoolCapacity(
        uint256 stakedAmount
    ) public view returns (uint256) {
        return stakedAmount * capacityParams.stakeMultiplier;
    }

    /// @notice Calculate owner's maximum total capacity
    /// @param owner Owner address
    /// @return Maximum capacity for all of owner's pools
    function calculateOwnerMaxCapacity(
        address owner
    ) public view returns (uint256) {
        // Get total supply of tokens
        uint256 totalMinted = IERC20(tokenAddress).totalSupply();

        // Get owner's governance votes
        uint256 ownerGovVotes = _stake.validGovVotes(tokenAddress, owner);
        uint256 totalGovVotes = _stake.govVotesNum(tokenAddress);

        if (totalGovVotes == 0) {
            return 0;
        }

        // Owner Gov Ratio = ownerGovVotes / totalGovVotes
        // Max Capacity = totalMinted × ownerGovRatio × capacityMultiplier
        return
            (totalMinted * ownerGovVotes * capacityParams.capacityMultiplier) /
            totalGovVotes;
    }

    /// @notice Calculate miner's maximum participation amount
    /// @return Maximum amount a single miner can participate with
    function calculateMinerMaxAmount() public view returns (uint256) {
        uint256 totalMinted = IERC20(tokenAddress).totalSupply();
        return totalMinted / capacityParams.minerCapMultiplier;
    }

    /// @notice Calculate owner's current total capacity usage
    /// @param owner Owner address
    /// @return Total capacity currently used by owner's pools
    function getOwnerCurrentCapacity(
        address owner
    ) public view returns (uint256) {
        uint256[] memory poolIds = _poolsByOwner[owner];
        uint256 totalCapacity = 0;

        for (uint256 i = 0; i < poolIds.length; i++) {
            PoolInfo storage pool = _pools[poolIds[i]];
            if (!pool.isStopped) {
                totalCapacity += pool.capacity;
            }
        }

        return totalCapacity;
    }

    /// @notice Calculate owner's current total staked amount
    /// @param owner Owner address
    /// @return Total amount staked across owner's active pools
    function getOwnerCurrentStake(address owner) public view returns (uint256) {
        uint256[] memory poolIds = _poolsByOwner[owner];
        uint256 totalStaked = 0;

        for (uint256 i = 0; i < poolIds.length; i++) {
            PoolInfo storage pool = _pools[poolIds[i]];
            if (!pool.isStopped) {
                totalStaked += pool.stakedAmount;
            }
        }

        return totalStaked;
    }

    // ============================================
    // CAPACITY VALIDATION
    // ============================================

    /// @notice Check if owner meets minimum governance ratio
    /// @param owner Owner address
    /// @return True if owner has sufficient governance votes
    function checkGovRatioForCreation(
        address owner
    ) public view returns (bool) {
        uint256 ownerGovVotes = _stake.validGovVotes(tokenAddress, owner);
        uint256 totalGovVotes = _stake.govVotesNum(tokenAddress);

        if (totalGovVotes == 0) {
            return false;
        }

        // Check if (ownerGovVotes / totalGovVotes) >= minGovRatio
        // Equivalent to: ownerGovVotes * 10000 >= totalGovVotes * minGovRatio
        return
            (ownerGovVotes * 10000) >=
            (totalGovVotes * capacityParams.minGovRatio);
    }

    /// @notice Check if capacity is available in a pool
    /// @param poolId Pool ID
    /// @param additionalAmount Amount to add
    /// @return True if capacity is sufficient
    function checkCapacityAvailable(
        uint256 poolId,
        uint256 additionalAmount
    ) public view returns (bool) {
        PoolInfo storage pool = _pools[poolId];
        return (pool.totalParticipation + additionalAmount) <= pool.capacity;
    }

    /// @notice Check if owner can create pool with given stake
    /// @param owner Owner address
    /// @param stakedAmount Amount to stake
    /// @return True if creation is allowed
    function canCreatePool(
        address owner,
        uint256 stakedAmount
    ) public view returns (bool) {
        // Check governance ratio
        if (!checkGovRatioForCreation(owner)) {
            return false;
        }

        // Check if new capacity would exceed owner's limit
        uint256 newCapacity = calculatePoolCapacity(stakedAmount);
        uint256 currentCapacity = getOwnerCurrentCapacity(owner);
        uint256 maxCapacity = calculateOwnerMaxCapacity(owner);

        return (currentCapacity + newCapacity) <= maxCapacity;
    }

    /// @notice Check if pool can be expanded
    /// @param owner Owner address
    /// @param poolId Pool ID
    /// @param newStakedAmount New total staked amount after expansion
    /// @return True if expansion is allowed
    function canExpandPool(
        address owner,
        uint256 poolId,
        uint256 newStakedAmount
    ) public view returns (bool) {
        PoolInfo storage pool = _pools[poolId];

        // Calculate capacity change
        uint256 oldCapacity = pool.capacity;
        uint256 newCapacity = calculatePoolCapacity(newStakedAmount);
        uint256 capacityIncrease = newCapacity - oldCapacity;

        // Check if increased capacity would exceed owner's limit
        uint256 currentCapacity = getOwnerCurrentCapacity(owner);
        uint256 maxCapacity = calculateOwnerMaxCapacity(owner);

        return (currentCapacity + capacityIncrease) <= maxCapacity;
    }

    // ============================================
    // INTERNAL IMPLEMENTATIONS
    // ============================================

    /// @inheritdoc PoolManagerMixin
    function _checkCanCreatePool(
        address owner,
        uint256 stakedAmount
    ) internal view virtual override {
        // Check governance ratio
        if (!checkGovRatioForCreation(owner)) {
            revert InsufficientGovRatio();
        }

        // Check capacity limits
        uint256 newCapacity = calculatePoolCapacity(stakedAmount);
        uint256 currentCapacity = getOwnerCurrentCapacity(owner);
        uint256 maxCapacity = calculateOwnerMaxCapacity(owner);

        if ((currentCapacity + newCapacity) > maxCapacity) {
            revert OwnerCapacityExceeded();
        }
    }

    /// @inheritdoc PoolManagerMixin
    function _checkCanExpandPool(
        address owner,
        uint256 poolId,
        uint256 newStakedAmount
    ) internal view virtual override {
        if (!canExpandPool(owner, poolId, newStakedAmount)) {
            revert OwnerCapacityExceeded();
        }
    }

    /// @inheritdoc PoolManagerMixin
    function _calculatePoolCapacity(
        uint256 stakedAmount
    ) internal view virtual override returns (uint256) {
        return calculatePoolCapacity(stakedAmount);
    }

    // ============================================
    // VIEW FUNCTIONS - CAPACITY INFO
    // ============================================

    /// @notice Get capacity information for an owner
    /// @param owner Owner address
    /// @return current Current total capacity
    /// @return max Maximum allowed capacity
    /// @return available Available capacity for new pools
    function getOwnerCapacityInfo(
        address owner
    ) external view returns (uint256 current, uint256 max, uint256 available) {
        current = getOwnerCurrentCapacity(owner);
        max = calculateOwnerMaxCapacity(owner);
        available = max > current ? max - current : 0;
        return (current, max, available);
    }

    /// @notice Get pool capacity information
    /// @param poolId Pool ID
    /// @return capacity Total pool capacity
    /// @return used Currently used capacity
    /// @return available Available capacity
    function getPoolCapacityInfo(
        uint256 poolId
    )
        external
        view
        returns (uint256 capacity, uint256 used, uint256 available)
    {
        PoolInfo storage pool = _pools[poolId];
        capacity = pool.capacity;
        used = pool.totalParticipation;
        available = capacity > used ? capacity - used : 0;
        return (capacity, used, available);
    }
}
