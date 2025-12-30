// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "./interface/IExtensionCenter.sol";
import {IExtension} from "./interface/IExtension.sol";
import {
    IExtensionFactory,
    DEFAULT_JOIN_AMOUNT
} from "./interface/IExtensionFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/interfaces/ILOVE20Mint.sol";

/// @title ExtensionBase
/// @notice Core base contract providing fundamental extension functionality
/// @dev Implements IExtension interface with factory/center references, initialization, and reward claiming
abstract contract ExtensionBase is IExtension, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The factory contract address
    address public immutable factory;

    /// @notice The center contract address
    IExtensionCenter internal immutable _center;

    /// @notice The token address this extension is associated with
    address public tokenAddress;

    /// @notice Whether the extension has been initialized
    bool public initialized;

    /// @notice The action ID this extension is associated with
    uint256 public actionId;

    /// @notice The submit contract address
    ILOVE20Submit internal immutable _submit;
    /// @notice The vote contract address
    ILOVE20Vote internal immutable _vote;
    /// @notice The join contract address
    ILOVE20Join internal immutable _join;
    /// @notice The verify contract address
    ILOVE20Verify internal immutable _verify;
    /// @notice The mint contract address
    ILOVE20Mint internal immutable _mint;

    /// @dev round => reward
    mapping(uint256 => uint256) internal _reward;

    /// @dev round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param tokenAddress_ The token address (required, cannot be address(0))
    constructor(address factory_, address tokenAddress_) {
        if (tokenAddress_ == address(0)) {
            revert InvalidTokenAddress();
        }
        factory = factory_;
        tokenAddress = tokenAddress_;
        _center = IExtensionCenter(IExtensionFactory(factory_).center());
        _submit = ILOVE20Submit(_center.submitAddress());
        _vote = ILOVE20Vote(_center.voteAddress());
        _join = ILOVE20Join(_center.joinAddress());
        _verify = ILOVE20Verify(_center.verifyAddress());
        _mint = ILOVE20Mint(_center.mintAddress());
    }

    // ============================================
    // ILOVE20EXTENSION INTERFACE - Core
    // ============================================

    /// @inheritdoc IExtension
    function center() public view returns (address) {
        return address(_center);
    }

    /// @inheritdoc IExtension
    function initializeAction() external {
        if (initialized) return;

        // Auto-initialize by scanning voted actions to find matching actionId
        // This will find the actionId, approve tokens, and join
        _autoInitialize();
    }

    // ============================================
    // ILOVE20EXTENSION INTERFACE - Reward
    // ============================================

    /// @inheritdoc IExtension
    function claimReward(
        uint256 round
    ) public virtual nonReentrant returns (uint256 amount) {
        // Verify phase must be finished for this round
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Prepare reward
        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    /// @inheritdoc IExtension
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 amount, bool isMinted) {
        // Check if already claimed
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        // Calculate reward using child contract implementation
        return (_calculateReward(round, account), false);
    }

    /// @inheritdoc IExtension
    function reward(uint256 round) public view virtual returns (uint256) {
        if (_reward[round] > 0) {
            return _reward[round];
        }
        (uint256 expectedReward, ) = _mint.actionRewardByActionIdByAccount(
            tokenAddress,
            round,
            actionId,
            address(this)
        );
        return expectedReward;
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================

    /// @dev Core initialization logic shared by initialize() and _autoInitialize()
    function _doInitialize(uint256 actionId_) internal {
        if (initialized) {
            revert AlreadyInitialized();
        }

        initialized = true;
        actionId = actionId_;

        // Approve token to joinAddress before joining
        IERC20(tokenAddress).safeIncreaseAllowance(
            address(_join),
            DEFAULT_JOIN_AMOUNT
        );

        // Join the action
        _join.join(
            tokenAddress,
            actionId,
            DEFAULT_JOIN_AMOUNT,
            new string[](0)
        );
    }

    /// @dev Find matching action ID by scanning voted actions
    /// @return The found action ID
    function _findMatchingActionId() internal view returns (uint256) {
        uint256 currentRound = _join.currentRound();
        uint256 count = _vote.votedActionIdsCount(tokenAddress, currentRound);
        uint256 foundActionId = 0;
        bool found = false;

        for (uint256 i = 0; i < count; i++) {
            uint256 aid = _vote.votedActionIdsAtIndex(
                tokenAddress,
                currentRound,
                i
            );
            ActionInfo memory info = _submit.actionInfo(tokenAddress, aid);
            if (info.body.whiteListAddress == address(this)) {
                if (found) revert MultipleActionIdsFound();
                foundActionId = aid;
                found = true;
            }
        }
        if (!found) revert ActionIdNotFound();
        return foundActionId;
    }

    /// @dev Auto-initialize by scanning voted actions to find matching actionId
    function _autoInitialize() internal {
        if (initialized) {
            return;
        }

        uint256 foundActionId = _findMatchingActionId();
        _doInitialize(foundActionId);
    }

    /// @dev Calculate reward for an account in a specific round
    /// @dev Must be implemented by child contracts
    /// @param round The round number
    /// @param account The account address
    /// @return The amount of reward for the account
    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual returns (uint256);

    /// @dev Prepare action reward for a specific round if not already prepared
    /// @param round The round number to prepare reward for
    function _prepareRewardIfNeeded(uint256 round) internal virtual {
        if (_reward[round] > 0) {
            return;
        }
        uint256 totalActionReward = _mint.mintActionReward(
            tokenAddress,
            round,
            actionId
        );
        _reward[round] = totalActionReward;
    }

    /// @dev Internal function to claim reward for a specific round
    /// @param round The round number to claim reward for
    /// @return amount The amount of reward claimed
    function _claimReward(
        uint256 round
    ) internal virtual returns (uint256 amount) {
        // Calculate reward for the user
        bool isMinted;
        (amount, isMinted) = rewardByAccount(round, msg.sender);
        // Check if already minted
        if (isMinted) {
            revert AlreadyClaimed();
        }
        // Update claimed reward
        _claimedReward[round][msg.sender] = amount;

        // Transfer reward to user
        if (amount > 0) {
            IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        }

        emit ClaimReward(tokenAddress, round, actionId, msg.sender, amount);
    }
}
