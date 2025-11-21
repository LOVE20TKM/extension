// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {ExtensionAccounts} from "./ExtensionAccounts.sol";
import {ExtensionVerificationInfo} from "./ExtensionVerificationInfo.sol";
import {IJoin} from "../interface/base/IJoin.sol";
import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";

/// @title Join
/// @notice Base contract providing token-free join/withdraw functionality
/// @dev Implements IJoin interface with block-based waiting period
abstract contract Join is
    ExtensionCore,
    ExtensionAccounts,
    ExtensionVerificationInfo,
    IJoin
{
    // ============================================
    // IJOIN INTERFACE
    // ============================================

    /// @inheritdoc IJoin
    function join(string[] memory verificationInfos) public virtual {
        // Check if already joined via center
        if (
            ILOVE20ExtensionCenter(center()).isAccountJoined(
                tokenAddress,
                actionId,
                msg.sender
            )
        ) {
            revert AlreadyJoined();
        }

        // Add to accounts list
        _addAccount(msg.sender);

        // Update verification info if provided
        updateVerificationInfo(verificationInfos);

        emit Join(tokenAddress, msg.sender, actionId);
    }

    /// @inheritdoc IJoin
    function withdraw() public virtual {
        // Check if joined via center
        if (
            !ILOVE20ExtensionCenter(center()).isAccountJoined(
                tokenAddress,
                actionId,
                msg.sender
            )
        ) {
            revert NotJoined();
        }

        // Remove from accounts list
        _removeAccount(msg.sender);

        emit Withdraw(tokenAddress, msg.sender, actionId);
    }
}
