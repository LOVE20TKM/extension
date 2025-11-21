// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {IExtensionReward} from "../interface/base/IExtensionReward.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";

/// @title ExtensionReward
/// @notice Base contract providing reward claiming functionality
/// @dev Implements IExtensionReward interface with reward storage and claiming logic
abstract contract ExtensionReward is ExtensionCore, IExtensionReward {
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
    ) public virtual returns (uint256 reward) {
        // Verify phase must be finished for this round
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Prepare reward
        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    /// @dev Virtual function to calculate reward for an account in a specific round
    /// @dev Must be implemented by child contracts
    /// @param round The round number
    /// @param account The account address
    /// @return reward The amount of reward for the account
    /// @return isMinted Whether the reward has already been minted
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 reward, bool isMinted);

    // ============================================
    // INTERNAL HELPER FUNCTIONS
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
