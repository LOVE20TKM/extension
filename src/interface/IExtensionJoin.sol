// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtension} from "./IExtension.sol";

interface IExtensionJoin is IExtension {
    error NotJoined();
    error AlreadyJoined();

    event Join(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account
    );

    event Exit(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account
    );

    function joinInfo(
        address account
    ) external view returns (uint256 joinedRound);

    function join(string[] memory verificationInfos) external;

    function exit() external;
}
