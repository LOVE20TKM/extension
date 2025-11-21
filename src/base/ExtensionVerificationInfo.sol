// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {
    IExtensionVerification
} from "../interface/base/IExtensionVerification.sol";
import {ILOVE20Submit} from "@core/interfaces/ILOVE20Submit.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";
import {ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";

/// @title ExtensionVerificationInfo
/// @notice Base contract providing verification information functionality
/// @dev Implements IExtensionVerification interface with verification info storage
abstract contract ExtensionVerificationInfo is
    ExtensionCore,
    IExtensionVerification
{
    using ArrayUtils for uint256[];

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev account => verificationKey => round => verificationInfo
    mapping(address => mapping(string => mapping(uint256 => string)))
        internal _verificationInfoByRound;

    /// @dev account => verificationKey => round[]
    mapping(address => mapping(string => uint256[]))
        internal _verificationInfoUpdateRounds;

    // ============================================
    // IEXTENSIONVERIFICATION INTERFACE
    // ============================================

    /// @inheritdoc IExtensionVerification
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

    /// @inheritdoc IExtensionVerification
    function verificationInfo(
        address account,
        string calldata verificationKey
    ) external view virtual returns (string memory) {
        uint256[] memory rounds = _verificationInfoUpdateRounds[account][
            verificationKey
        ];
        if (rounds.length == 0) {
            return "";
        }

        uint256 latestRound = rounds[rounds.length - 1];
        return _verificationInfoByRound[account][verificationKey][latestRound];
    }

    /// @inheritdoc IExtensionVerification
    function verificationInfoByRound(
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view virtual returns (string memory) {
        uint256[] storage rounds = _verificationInfoUpdateRounds[account][
            verificationKey
        ];

        (bool found, uint256 nearestRound) = rounds.findLeftNearestOrEqualValue(
            round
        );
        if (!found) {
            return "";
        }
        return _verificationInfoByRound[account][verificationKey][nearestRound];
    }

    /// @inheritdoc IExtensionVerification
    function verificationInfoUpdateRoundsCount(
        address account,
        string calldata verificationKey
    ) external view virtual returns (uint256) {
        return _verificationInfoUpdateRounds[account][verificationKey].length;
    }

    /// @inheritdoc IExtensionVerification
    function verificationInfoUpdateRoundsAtIndex(
        address account,
        string calldata verificationKey,
        uint256 index
    ) external view virtual returns (uint256) {
        return _verificationInfoUpdateRounds[account][verificationKey][index];
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
        uint256[] storage rounds = _verificationInfoUpdateRounds[msg.sender][
            verificationKey
        ];

        if (rounds.length == 0 || rounds[rounds.length - 1] != currentRound) {
            rounds.push(currentRound);
        }

        _verificationInfoByRound[msg.sender][verificationKey][
            currentRound
        ] = aVerificationInfo;

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
