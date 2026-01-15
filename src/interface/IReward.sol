// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IReward {
    event ClaimReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );
    error AlreadyClaimed();

    function reward(uint256 round) external view returns (uint256);
    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool claimed);

    function claimReward(uint256 round) external returns (uint256 reward);
}
