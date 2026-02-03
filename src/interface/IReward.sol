// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IRewardEvents {
    event ClaimReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 mintAmount,
        uint256 burnAmount
    );
    event BurnReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        uint256 amount
    );
}

interface IRewardErrors {
    error AlreadyClaimed();
}

interface IReward is IRewardEvents, IRewardErrors {
    function reward(uint256 round) external view returns (uint256);
    function rewardByAccount(
        uint256 round,
        address account
    )
        external
        view
        returns (uint256 mintReward, uint256 burnReward, bool claimed);

    function claimReward(
        uint256 round
    ) external returns (uint256 mintReward, uint256 burnReward);
    function claimRewards(
        uint256[] calldata rounds
    )
        external
        returns (
            uint256[] memory claimedRounds,
            uint256[] memory mintRewards,
            uint256[] memory burnRewards
        );

    function burnRewardIfNeeded(uint256 round) external;
    function burnInfo(
        uint256 round
    ) external view returns (uint256 burnAmount, bool burned);
}
