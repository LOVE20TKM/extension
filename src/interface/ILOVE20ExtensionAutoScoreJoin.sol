// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionAutoScore} from "./ILOVE20ExtensionAutoScore.sol";

interface ILOVE20ExtensionAutoScoreJoin is ILOVE20ExtensionAutoScore {
    error JoinAmountZero();

    error NoJoinedAmount();

    error NotEnoughWaitingBlocks();

    error AlreadyJoined();

    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount,
        uint256 joinedBlock
    );

    event Withdraw(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );

    struct JoinInfo {
        uint256 amount;
        uint256 joinedBlock;
    }

    function joinTokenAddress() external view returns (address);

    function waitingBlocks() external view returns (uint256);

    function join(uint256 amount, string[] memory verificationInfos) external;

    function withdraw() external;

    function joinInfo(
        address account
    )
        external
        view
        returns (
            uint256 amount,
            uint256 joinedBlock,
            uint256 withdrawableBlock
        );

    function totalJoinedAmount() external view returns (uint256);

    function canWithdraw(address account) external view returns (bool);
}
