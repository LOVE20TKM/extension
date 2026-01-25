// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ITokenJoinEvents {
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
}

interface ITokenJoinErrors {
    error InvalidJoinTokenAddress();
    error JoinAmountZero();
    error NotJoined();
    error NotEnoughWaitingBlocks(uint256 currentBlock, uint256 exitableBlock);
}

interface ITokenJoin is ITokenJoinEvents, ITokenJoinErrors {
    function JOIN_TOKEN_ADDRESS() external view returns (address);

    function WAITING_BLOCKS() external view returns (uint256);

    function joinedAmountByRound(uint256 round) external view returns (uint256);

    function joinedAmountByAccountByRound(
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
            uint256 lastJoinedBlock,
            uint256 exitableBlock
        );

    function join(uint256 amount, string[] memory verificationInfos) external;

    function exit() external;
}
