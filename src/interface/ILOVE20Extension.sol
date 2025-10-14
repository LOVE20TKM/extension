// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20Extension {
    // ------ Center required functions to initialize extension in the center ------

    // join action as the only whitelist address, only Center can call
    function initialize() external;

    function factory() external view returns (address);

    function tokenAddress() external returns (address);
    function actionId() external returns (uint256);
    function initialized() external returns (bool);

    // ------ user operation ------
    function requestRemove() external returns (bool);
    function claimReward(uint256 round) external returns (uint256 reward);

    // ------ joined status ------
    function isJoined(address account) external view returns (bool);
    function accountsCount() external view returns (uint256);
    function accountAtIndex(uint256) external view returns (address);
    // calculated based on tokenAddress token units directly or indirectly participated
    function joinedValue() external view returns (uint256, bool calculated);
    function joinedValueByAccount(
        address account
    ) external view returns (uint256, bool calculated);

    // ------ reward ------
    function rewardReserved() external view returns (uint256);
    function rewardClaimed() external view returns (uint256);
    function reward(uint256 round) external view returns (uint256);

    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted);

    // ?? prepare reward
    // ?? function prepareRewardIfNeeded(uint256 round) external;
    // ?? function isRewardPrepared(uint256 round) external view returns (bool);

    // ?? reward accounts
    // ?? function rewardAccountsCount(uint256 round) external view returns (uint256);
    // ?? functioin rewardAccountsAtIndex(uint256 round, uint256 index)  external view returns(address);
}
