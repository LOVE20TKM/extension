// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {
    IExtensionVerificationInfo
} from "../interface/base/IExtensionVerificationInfo.sol";
import {ILOVE20Submit} from "@core/interfaces/ILOVE20Submit.sol";
import {ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {RoundHistoryString} from "../lib/RoundHistoryString.sol";

/// @title ExtensionVerificationInfo
/// @notice Base contract providing verification information functionality
/// @dev Implements IExtensionVerificationInfo interface with verification info storage
abstract contract ExtensionVerificationInfo is
    ExtensionCore,
    IExtensionVerificationInfo
{
    using RoundHistoryString for RoundHistoryString.History;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev account => verificationKey => History
    mapping(address => mapping(string => RoundHistoryString.History))
        internal _verificationInfoHistory;

    // ============================================
    // IEXTENSIONVERIFICATION INTERFACE
    // ============================================

    /// @inheritdoc IExtensionVerificationInfo
    function updateVerificationInfo(
        string[] memory verificationInfos
    ) public virtual {
        if (verificationInfos.length == 0) {
            return;
        }

        // Get verificationKeys from action info
        ActionInfo memory actionInfo = _submit.actionInfo(
            tokenAddress,
            actionId
        );
        string[] memory verificationKeys = actionInfo.body.verificationKeys;

        if (verificationKeys.length != verificationInfos.length) {
            revert VerificationInfoLengthMismatch();
        }
        for (uint256 i = 0; i < verificationKeys.length; i++) {
            _updateVerificationInfoByKey(
                verificationKeys[i],
                verificationInfos[i]
            );
        }
    }

    /// @inheritdoc IExtensionVerificationInfo
    function verificationInfo(
        address account,
        string calldata verificationKey
    ) external view virtual returns (string memory) {
        return _verificationInfoHistory[account][verificationKey].latestValue();
    }

    /// @inheritdoc IExtensionVerificationInfo
    function verificationInfoByRound(
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view virtual returns (string memory) {
        return _verificationInfoHistory[account][verificationKey].value(round);
    }

    /// @inheritdoc IExtensionVerificationInfo
    function verificationInfoUpdateRoundsCount(
        address account,
        string calldata verificationKey
    ) external view virtual returns (uint256) {
        return
            _verificationInfoHistory[account][verificationKey]
                .changeRoundsCount();
    }

    /// @inheritdoc IExtensionVerificationInfo
    function verificationInfoUpdateRoundsAtIndex(
        address account,
        string calldata verificationKey,
        uint256 index
    ) external view virtual returns (uint256) {
        return
            _verificationInfoHistory[account][verificationKey]
                .changeRoundAtIndex(index);
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Internal function to update verification info for a single key
    /// @param verificationKey The verification key
    /// @param aVerificationInfo The verification information
    function _updateVerificationInfoByKey(
        string memory verificationKey,
        string memory aVerificationInfo
    ) internal virtual {
        uint256 currentRound = _join.currentRound();
        _verificationInfoHistory[msg.sender][verificationKey].record(
            currentRound,
            aVerificationInfo
        );

        emit UpdateVerificationInfo({
            tokenAddress: tokenAddress,
            account: msg.sender,
            actionId: actionId,
            verificationKey: verificationKey,
            round: currentRound,
            verificationInfo: aVerificationInfo
        });
    }
}
