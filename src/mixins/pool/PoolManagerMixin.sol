// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "../ExtensionCoreMixin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title PoolManagerMixin
/// @notice Core mixin for managing mining pools
/// @dev Provides pool creation, management, and metadata functionality
///
/// **Features:**
/// - Create pools with custom parameters
/// - Manage pool lifecycle (active/stopped)
/// - Set pool verifiers
/// - Update pool descriptions
/// - Stake tokens to determine pool capacity
///
abstract contract PoolManagerMixin is ExtensionCoreMixin {
    // ============================================
    // ERRORS
    // ============================================
    error PoolNotFound();
    error PoolAlreadyStopped();
    error PoolNotStopped();
    error OnlyPoolOwner();
    error OnlyPoolOwnerOrVerifier();
    error PoolNotActive();
    error InvalidPoolParameters();
    error CannotStopInCreationRound();

    // ============================================
    // EVENTS
    // ============================================
    event PoolCreated(
        uint256 indexed poolId,
        address indexed owner,
        string name,
        uint256 stakedAmount,
        uint256 capacity,
        uint256 createdRound
    );

    event PoolExpanded(
        uint256 indexed poolId,
        uint256 additionalStake,
        uint256 newCapacity
    );

    event PoolStopped(
        uint256 indexed poolId,
        uint256 stoppedRound,
        uint256 returnedStake
    );

    event PoolDescriptionUpdated(uint256 indexed poolId, string newDescription);

    event PoolVerifierSet(uint256 indexed poolId, address indexed verifier);

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Pool information structure
    struct PoolInfo {
        uint256 poolId; // Pool unique ID
        address owner; // Pool owner (creator)
        address verifier; // Designated verifier (optional)
        string name; // Pool name (immutable after creation)
        string description; // Pool description (updatable)
        string[] additionalInfoKeys; // Keys for additional info miners must provide
        uint256 stakedAmount; // Total staked tokens
        uint256 capacity; // Current pool capacity
        uint256 minMinerAmount; // Minimum amount for miners to participate
        uint256 totalParticipation; // Total participation tokens from miners
        bool isStopped; // Whether pool is stopped
        uint256 createdRound; // Round when pool was created
        uint256 stoppedRound; // Round when pool was stopped (0 if active)
    }

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice Counter for pool IDs
    uint256 public nextPoolId;

    /// @notice Mapping from pool ID to pool information
    mapping(uint256 => PoolInfo) internal _pools;

    /// @notice Mapping from owner address to their pool IDs
    mapping(address => uint256[]) internal _poolsByOwner;

    /// @notice List of all pool IDs
    uint256[] internal _allPoolIds;

    /// @notice Token contract for staking
    IERC20 internal _token;

    // ============================================
    // MODIFIERS
    // ============================================

    /// @dev Only pool owner can call
    modifier onlyPoolOwner(uint256 poolId) {
        if (_pools[poolId].owner != msg.sender) {
            revert OnlyPoolOwner();
        }
        _;
    }

    /// @dev Only pool owner or designated verifier can call
    modifier onlyPoolOwnerOrVerifier(uint256 poolId) {
        PoolInfo storage pool = _pools[poolId];
        if (pool.owner != msg.sender && pool.verifier != msg.sender) {
            revert OnlyPoolOwnerOrVerifier();
        }
        _;
    }

    /// @dev Pool must be active (not stopped)
    modifier poolActive(uint256 poolId) {
        if (_pools[poolId].isStopped) {
            revert PoolNotActive();
        }
        _;
    }

    /// @dev Pool must exist
    modifier poolExists(uint256 poolId) {
        if (_pools[poolId].owner == address(0)) {
            revert PoolNotFound();
        }
        _;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor() {
        nextPoolId = 1; // Start from 1, 0 is reserved for "no pool"
    }

    // ============================================
    // POOL CREATION AND MANAGEMENT
    // ============================================

    /// @notice Create a new mining pool
    /// @param name Pool name (immutable)
    /// @param description Pool description (updatable)
    /// @param stakedAmount Amount of tokens to stake (determines capacity)
    /// @param minMinerAmount Minimum amount for miners to participate
    /// @param additionalInfoKeys Keys for additional info miners must provide
    /// @return poolId The created pool ID
    function createPool(
        string memory name,
        string memory description,
        uint256 stakedAmount,
        uint256 minMinerAmount,
        string[] memory additionalInfoKeys
    ) public virtual returns (uint256 poolId) {
        // Validate parameters
        if (bytes(name).length == 0) {
            revert InvalidPoolParameters();
        }
        if (stakedAmount == 0) {
            revert InvalidPoolParameters();
        }

        // Check capacity requirements (implemented in PoolCapacityMixin)
        _checkCanCreatePool(msg.sender, stakedAmount);

        // Transfer staked tokens
        if (address(_token) == address(0)) {
            _token = IERC20(tokenAddress);
        }
        _token.transferFrom(msg.sender, address(this), stakedAmount);

        // Create pool
        poolId = nextPoolId++;
        uint256 capacity = _calculatePoolCapacity(stakedAmount);
        uint256 currentRound = _join.currentRound();

        PoolInfo storage pool = _pools[poolId];
        pool.poolId = poolId;
        pool.owner = msg.sender;
        pool.name = name;
        pool.description = description;
        pool.additionalInfoKeys = additionalInfoKeys;
        pool.stakedAmount = stakedAmount;
        pool.capacity = capacity;
        pool.minMinerAmount = minMinerAmount;
        pool.isStopped = false;
        pool.createdRound = currentRound;

        // Track pool
        _poolsByOwner[msg.sender].push(poolId);
        _allPoolIds.push(poolId);

        emit PoolCreated(
            poolId,
            msg.sender,
            name,
            stakedAmount,
            capacity,
            currentRound
        );

        return poolId;
    }

    /// @notice Expand pool capacity by staking more tokens
    /// @param poolId The pool ID
    /// @param additionalStake Additional amount to stake
    function expandPool(
        uint256 poolId,
        uint256 additionalStake
    )
        public
        virtual
        poolExists(poolId)
        onlyPoolOwner(poolId)
        poolActive(poolId)
    {
        if (additionalStake == 0) {
            revert InvalidPoolParameters();
        }

        PoolInfo storage pool = _pools[poolId];

        // Check if expansion exceeds owner's capacity limit
        uint256 newStakedAmount = pool.stakedAmount + additionalStake;
        _checkCanExpandPool(msg.sender, poolId, newStakedAmount);

        // Transfer additional tokens
        _token.transferFrom(msg.sender, address(this), additionalStake);

        // Update pool
        pool.stakedAmount = newStakedAmount;
        uint256 newCapacity = _calculatePoolCapacity(newStakedAmount);
        pool.capacity = newCapacity;

        emit PoolExpanded(poolId, additionalStake, newCapacity);
    }

    /// @notice Stop a pool and return staked tokens
    /// @param poolId The pool ID
    function stopPool(
        uint256 poolId
    ) public virtual poolExists(poolId) onlyPoolOwner(poolId) {
        PoolInfo storage pool = _pools[poolId];

        if (pool.isStopped) {
            revert PoolAlreadyStopped();
        }

        uint256 currentRound = _join.currentRound();

        // Cannot stop in the same round as creation
        if (currentRound == pool.createdRound) {
            revert CannotStopInCreationRound();
        }

        // Mark as stopped
        pool.isStopped = true;
        pool.stoppedRound = currentRound;

        // Return staked tokens
        uint256 stakedAmount = pool.stakedAmount;
        _token.transfer(msg.sender, stakedAmount);

        emit PoolStopped(poolId, currentRound, stakedAmount);
    }

    // ============================================
    // POOL METADATA MANAGEMENT
    // ============================================

    /// @notice Update pool description
    /// @param poolId The pool ID
    /// @param newDescription New description
    function updatePoolDescription(
        uint256 poolId,
        string memory newDescription
    ) public virtual poolExists(poolId) onlyPoolOwner(poolId) {
        _pools[poolId].description = newDescription;
        emit PoolDescriptionUpdated(poolId, newDescription);
    }

    /// @notice Set designated verifier for a pool
    /// @param poolId The pool ID
    /// @param verifier Verifier address (can be zero to remove)
    function setPoolVerifier(
        uint256 poolId,
        address verifier
    ) public virtual poolExists(poolId) onlyPoolOwner(poolId) {
        _pools[poolId].verifier = verifier;
        emit PoolVerifierSet(poolId, verifier);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get pool information
    /// @param poolId The pool ID
    /// @return Pool information struct
    function getPoolInfo(
        uint256 poolId
    ) external view returns (PoolInfo memory) {
        return _pools[poolId];
    }

    /// @notice Get pool IDs owned by an address
    /// @param owner Owner address
    /// @return Array of pool IDs
    function getPoolsByOwner(
        address owner
    ) external view virtual returns (uint256[] memory) {
        return _poolsByOwner[owner];
    }

    /// @notice Get all pool IDs
    /// @return Array of all pool IDs
    function getAllPoolIds() external view returns (uint256[] memory) {
        return _allPoolIds;
    }

    /// @notice Get count of all pools
    /// @return Total number of pools
    function getPoolCount() external view returns (uint256) {
        return _allPoolIds.length;
    }

    /// @notice Check if a pool exists
    /// @param poolId The pool ID
    /// @return True if pool exists
    function isPoolExist(uint256 poolId) external view returns (bool) {
        return _pools[poolId].owner != address(0);
    }

    /// @notice Check if a pool is active
    /// @param poolId The pool ID
    /// @return True if pool is active (not stopped)
    function isPoolActive(uint256 poolId) external view returns (bool) {
        return !_pools[poolId].isStopped;
    }

    /// @notice Check if an address can verify a pool
    /// @param verifier Address to check
    /// @param poolId Pool ID
    /// @return True if address can verify
    function canVerify(
        address verifier,
        uint256 poolId
    ) public view returns (bool) {
        PoolInfo storage pool = _pools[poolId];
        return verifier == pool.owner || verifier == pool.verifier;
    }

    // ============================================
    // INTERNAL HOOKS (to be implemented by capacity mixin)
    // ============================================

    /// @dev Check if address can create a pool with given stake
    /// @param owner Pool owner address
    /// @param stakedAmount Amount to stake
    function _checkCanCreatePool(
        address owner,
        uint256 stakedAmount
    ) internal view virtual;

    /// @dev Check if pool can be expanded
    /// @param owner Pool owner address
    /// @param poolId Pool ID
    /// @param newStakedAmount New total staked amount
    function _checkCanExpandPool(
        address owner,
        uint256 poolId,
        uint256 newStakedAmount
    ) internal view virtual;

    /// @dev Calculate pool capacity based on staked amount
    /// @param stakedAmount Amount staked
    /// @return Calculated capacity
    function _calculatePoolCapacity(
        uint256 stakedAmount
    ) internal view virtual returns (uint256);
}
