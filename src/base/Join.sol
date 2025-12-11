// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {VerificationInfo} from "./VerificationInfo.sol";
import {IJoin} from "../interface/base/IJoin.sol";
import {IExit} from "../interface/base/IExit.sol";

/// @title Join
/// @notice Base contract providing token-free join/exit functionality
/// @dev Implements IJoin interface with block-based waiting period
abstract contract Join is ExtensionCore, VerificationInfo, IJoin {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Mapping from account to the round when they joined
    mapping(address => uint256) internal _joinedRound;

    // ============================================
    // IJOIN INTERFACE
    // ============================================

    /// @inheritdoc IJoin
    function joinInfo(
        address account
    ) public view virtual returns (uint256 joinedRound) {
        return _joinedRound[account];
    }

    /// @inheritdoc IJoin
    function join(string[] memory verificationInfos) public virtual {
        // Auto-initialize if not initialized
        _autoInitialize();

        // Check if already joined
        if (_joinedRound[msg.sender] != 0) {
            revert AlreadyJoined();
        }

        // Record joined round
        _joinedRound[msg.sender] = _join.currentRound();

        // Add to center accounts
        _center.addAccount(tokenAddress, actionId, msg.sender);

        // Update verification info if provided
        updateVerificationInfo(verificationInfos);

        emit Join(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }

    /// @inheritdoc IExit
    function exit() public virtual {
        // Check if joined
        if (_joinedRound[msg.sender] == 0) {
            revert NotJoined();
        }

        // Clear joined round
        _joinedRound[msg.sender] = 0;

        // Remove from center accounts
        _center.removeAccount(tokenAddress, actionId, msg.sender);

        emit Exit(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }
}
