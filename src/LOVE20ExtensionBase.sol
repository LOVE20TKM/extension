// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./base/ExtensionCore.sol";
import {ExtensionAccounts} from "./base/ExtensionAccounts.sol";
import {ExtensionVerification} from "./base/ExtensionVerification.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";
import {IExtensionReward} from "./interface/base/IExtensionReward.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";

/// @title LOVE20ExtensionBase
/// @notice Abstract base contract for LOVE20 extensions
/// @dev Provides common storage and implementation for all extensions
abstract contract LOVE20ExtensionBase is
    ExtensionCore,
    ExtensionAccounts,
    ExtensionVerification,
    ILOVE20Extension
{
    // ============================================
    // STATE VARIABLES - REWARD
    // ============================================

    /// @dev round => reward
    mapping(uint256 => uint256) internal _reward;

    /// @dev round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    constructor(address factory_) ExtensionCore(factory_) {}

    // ============================================
    // REWARD FUNCTIONS
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

    function _prepareVerifyResultIfNeeded() internal virtual {
        // do nothing
    }

    /// @dev Virtual function to calculate reward for an account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return reward The amount of reward for the account
    /// @return isMinted Whether the reward has already been minted
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 reward, bool isMinted);

    function claimReward(
        uint256 round
    ) public virtual returns (uint256 reward) {
        // Verify phase must be finished for this round
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Prepare verify result and reward
        // Note: _prepareVerifyResultIfNeeded() only generates result for current round
        // For completed rounds, verification result should have been generated in that round's verify phase
        _prepareVerifyResultIfNeeded();
        _prepareRewardIfNeeded(round);

        return _claimReward(round);
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
