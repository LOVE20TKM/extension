// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {ExtensionAccounts} from "./ExtensionAccounts.sol";
import {VerificationInfo} from "./VerificationInfo.sol";
import {IJoin} from "../interface/base/IJoin.sol";
import {IExit} from "../interface/base/IExit.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";

/// @title Join
/// @notice Base contract providing token-free join/exit functionality
/// @dev Implements IJoin interface with block-based waiting period
abstract contract Join is
    ExtensionCore,
    ExtensionAccounts,
    VerificationInfo,
    IJoin
{
    // ============================================
    // IJOIN INTERFACE
    // ============================================

    /// @inheritdoc IJoin
    function isJoined(address account) public view virtual returns (bool) {
        return _center.isAccountJoined(tokenAddress, actionId, account);
    }

    /// @inheritdoc IJoin
    function join(string[] memory verificationInfos) public virtual {
        // Auto-initialize if not initialized
        _autoInitialize();

        // Check if already joined via center
        if (_center.isAccountJoined(tokenAddress, actionId, msg.sender)) {
            revert AlreadyJoined();
        }

        // Add to accounts list
        _addAccount(msg.sender);

        // Update verification info if provided
        updateVerificationInfo(verificationInfos);

        emit Join(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }

    /// @inheritdoc IExit
    function exit() public virtual {
        // Check if joined via center
        if (!_center.isAccountJoined(tokenAddress, actionId, msg.sender)) {
            revert NotJoined();
        }

        // Remove from accounts list
        _removeAccount(msg.sender);

        emit Exit(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }
}
