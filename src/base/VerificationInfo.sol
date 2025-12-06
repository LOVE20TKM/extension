// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {IVerificationInfo} from "../interface/base/IVerificationInfo.sol";
import {ILOVE20Submit} from "@core/interfaces/ILOVE20Submit.sol";
import {ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {RoundHistoryString} from "../lib/RoundHistoryString.sol";

/// @title VerificationInfo
/// @notice Base contract providing verification information functionality
/// @dev Implements IVerificationInfo interface with verification info storage
abstract contract VerificationInfo is ExtensionCore, IVerificationInfo {
    using RoundHistoryString for RoundHistoryString.History;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev account => verificationKey => History
    mapping(address => mapping(string => RoundHistoryString.History))
        internal _verificationInfoHistory;

    // ============================================
    // IVERIFICATIONINFO INTERFACE
    // ============================================

    /// @inheritdoc IVerificationInfo
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

    /// @inheritdoc IVerificationInfo
    function verificationInfo(
        address account,
        string calldata verificationKey
    ) external view virtual returns (string memory) {
        return _verificationInfoHistory[account][verificationKey].latestValue();
    }

    /// @inheritdoc IVerificationInfo
    function verificationInfoByRound(
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view virtual returns (string memory) {
        return _verificationInfoHistory[account][verificationKey].value(round);
    }

    /// @inheritdoc IVerificationInfo
    function verificationInfoUpdateRoundsCount(
        address account,
        string calldata verificationKey
    ) external view virtual returns (uint256) {
        return
            _verificationInfoHistory[account][verificationKey]
                .changeRoundsCount();
    }

    /// @inheritdoc IVerificationInfo
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
            round: currentRound,
            actionId: actionId,
            account: msg.sender,
            verificationKey: verificationKey,
            verificationInfo: aVerificationInfo
        });
    }
}

