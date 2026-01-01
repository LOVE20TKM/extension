// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtension} from "./IExtension.sol";

interface IExtensionTokenJoin is IExtension {
    error InvalidJoinTokenAddress();
    error JoinAmountZero();
    error NoJoinedAmount();
    error NotEnoughWaitingBlocks();

    event Join(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    event Exit(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    function joinTokenAddress() external view returns (address);

    function WAITING_BLOCKS() external view returns (uint256);

    function totalJoinedAmount() external view returns (uint256);

    function totalJoinedAmountByRound(
        uint256 round
    ) external view returns (uint256);

    function amountByAccountByRound(
        address account,
        uint256 round
    ) external view returns (uint256);

    function joinInfo(
        address account
    )
        external
        view
        returns (
            uint256 joinedRound,
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        );

    function join(uint256 amount, string[] memory verificationInfos) external;

    function exit() external;
}
