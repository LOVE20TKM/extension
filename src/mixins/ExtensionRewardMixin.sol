// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";

/// @title ExtensionRewardMixin
/// @notice Base reward distribution framework
/// @dev Provides the core reward claiming logic without enforcing a specific distribution strategy
///
/// ARCHITECTURE:
/// This mixin defines the reward claiming workflow and storage,
/// but delegates the actual reward calculation to derived contracts.
///
/// RESPONSIBILITIES:
/// - Manage reward claiming state (_reward, _claimedReward)
/// - Provide claimReward() function with standard workflow
/// - Define hooks for preparation (_prepareRewardIfNeeded)
/// - Handle token transfers
///
/// EXTENSION POINTS:
/// Derived contracts must implement:
/// - rewardByAccount() - Calculate reward for specific account
///
abstract contract ExtensionRewardMixin is ExtensionCoreMixin {
    // ============================================
    // ERRORS
    // ============================================
    error RoundNotFinished();
    error AlreadyClaimed();

    // ============================================
    // EVENTS
    // ============================================
    event ClaimReward(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 round,
        uint256 reward
    );

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev round => total reward for that round
    mapping(uint256 => uint256) internal _reward;

    /// @dev round => account => claimed reward amount
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // ============================================
    // ABSTRACT FUNCTIONS - MUST BE IMPLEMENTED
    // ============================================

    /// @notice Calculate reward for a specific account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return reward The calculated reward amount
    /// @return isMinted Whether the reward has already been minted/claimed
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 reward, bool isMinted) {
        // Check if already claimed
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        // Calculate reward using child contract implementation
        return (_calculateReward(round, account), false);
    }

    /// @dev Calculate reward for an account in a specific round
    /// @dev Must be implemented by child contracts
    /// @param round The round number
    /// @param account The account address
    /// @return reward The amount of reward for the account
    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual returns (uint256 reward);

    // ============================================
    // PUBLIC FUNCTIONS
    // ============================================

    /// @notice Claim reward for a specific round
    /// @param round The round number to claim reward from
    /// @return reward The amount of reward claimed
    function claimReward(
        uint256 round
    ) public virtual returns (uint256 reward) {
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    // ============================================
    // INTERNAL FUNCTIONS - HOOKS
    // ============================================

    /// @dev Hook to prepare reward data for a specific round
    /// Default implementation mints action reward from the mint contract
    /// @param round The round number
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

    /// @dev Internal function to execute the reward claim
    /// @param round The round number
    /// @return reward The amount of reward claimed
    function _claimReward(
        uint256 round
    ) internal virtual returns (uint256 reward) {
        // Calculate reward for the user
        bool isMinted;
        (reward, isMinted) = rewardByAccount(round, msg.sender);

        // Check if already minted
        if (isMinted) {
            revert AlreadyClaimed();
        }

        // Update claimed reward
        _claimedReward[round][msg.sender] = reward;

        // Transfer reward to user
        if (reward > 0) {
            ILOVE20Token token = ILOVE20Token(tokenAddress);
            token.transfer(msg.sender, reward);
        }

        emit ClaimReward(tokenAddress, msg.sender, actionId, round, reward);
    }
}
