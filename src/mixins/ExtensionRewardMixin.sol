// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";

/// @title ExtensionRewardMixin
/// @notice Mixin for handling reward distribution
/// @dev Provides reward preparation and claiming functionality
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

    /// @dev round => reward
    mapping(uint256 => uint256) internal _reward;

    /// @dev round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // ============================================
    // ABSTRACT FUNCTIONS
    // ============================================

    /// @dev Virtual function to calculate reward for an account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return reward The amount of reward for the account
    /// @return isMinted Whether the reward has already been minted
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 reward, bool isMinted);

    /// @dev Prepare verify result if needed (hook for subclasses)
    function _prepareVerifyResultIfNeeded() internal virtual {}

    // ============================================
    // PUBLIC FUNCTIONS
    // ============================================

    /// @notice Claim reward for a specific round
    /// @param round The round number
    /// @return reward The amount of reward claimed
    function claimReward(uint256 round) external returns (uint256 reward) {
        // Verify phase must be finished for this round
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Prepare verify result and reward
        _prepareVerifyResultIfNeeded();
        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================

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
    /// @return reward The amount of reward claimed
    function _claimReward(uint256 round) internal returns (uint256 reward) {
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
