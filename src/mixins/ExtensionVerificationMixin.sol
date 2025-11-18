// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";
import {ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";

abstract contract ExtensionVerificationMixin is ExtensionCoreMixin {
    using ArrayUtils for uint256[];

    error VerificationInfoLengthMismatch();

    event UpdateVerificationInfo(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        string verificationKey,
        uint256 round,
        string verificationInfo
    );

    mapping(address => mapping(string => mapping(uint256 => string)))
        internal _verificationInfoByRound;

    mapping(address => mapping(string => uint256[]))
        internal _verificationInfoUpdateRounds;

    function updateVerificationInfo(string[] memory verificationInfos) public {
        if (verificationInfos.length == 0) {
            return;
        }

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

    function verificationInfo(
        address account,
        string calldata verificationKey
    ) external view returns (string memory) {
        uint256[] memory rounds = _verificationInfoUpdateRounds[account][
            verificationKey
        ];
        if (rounds.length == 0) {
            return "";
        }

        uint256 latestRound = rounds[rounds.length - 1];
        return _verificationInfoByRound[account][verificationKey][latestRound];
    }

    function verificationInfoByRound(
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view returns (string memory) {
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

    function verificationInfoUpdateRoundsCount(
        address account,
        string calldata verificationKey
    ) external view returns (uint256) {
        return _verificationInfoUpdateRounds[account][verificationKey].length;
    }

    function verificationInfoUpdateRoundsAtIndex(
        address account,
        string calldata verificationKey,
        uint256 index
    ) external view returns (uint256) {
        return _verificationInfoUpdateRounds[account][verificationKey][index];
    }

    function _updateVerificationInfoByKey(
        string memory verificationKey,
        string memory aVerificationInfo
    ) internal {
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
