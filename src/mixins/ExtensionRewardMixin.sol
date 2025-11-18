// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";

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

    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 reward, bool isMinted);

    // ============================================
    // PUBLIC FUNCTIONS
    // ============================================

    function claimReward(
        uint256 round
    ) external virtual returns (uint256 reward) {
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        _prepareVerifyResultIfNeeded();
        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================

    function _prepareVerifyResultIfNeeded() internal virtual {}
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
