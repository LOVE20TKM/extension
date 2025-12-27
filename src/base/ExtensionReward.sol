// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {IExtensionReward} from "../interface/base/IExtensionReward.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title ExtensionReward
/// @notice Base contract providing reward claiming functionality
/// @dev Implements IExtensionReward interface with reward storage and claiming logic
abstract contract ExtensionReward is ExtensionCore, ReentrancyGuard, IExtensionReward {
    using SafeERC20 for IERC20;
    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionCore(factory_, tokenAddress_) {}

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev round => reward
    mapping(uint256 => uint256) internal _reward;

    /// @dev round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // ============================================
    // IEXTENSIONREWARD INTERFACE
    // ============================================

    /// @inheritdoc IExtensionReward
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

    /// @notice Get reward information for an account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return amount The amount of reward for the account
    /// @return isMinted Whether the reward has already been minted
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

    /// @inheritdoc IExtensionReward
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
    // INTERNAL HELPER FUNCTIONS
    // ============================================

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
