// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20Extension {
    // constructor params
    function center() external view returns (address);
    function factory() external view returns (address);
    function tokenAddress() external returns (address);
    function actionId() external returns (uint256);

    // join action as the only whitelist address, only Center can call
    function initialize() external;

    // ------ user operation ------
    // join&remove action shuold be implemented in the extension with different input params

    // ------ joined value status ------
    // calculated based on tokenAddress token units directly or indirectly participated
    function joinedValue() external view returns (uint256, bool calculated);
    function joinedValueByAccount(
        address account
    ) external view returns (uint256, bool calculated);

    // ------ account status ------
    function accountsCount() external view returns (uint256);
    function accountAtIndex(uint256) external view returns (address);
    function accountStatus(
        address account
    ) external view returns (bool added, bool requestRemove, bool removed);

    // ------ reward ------
    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted);
    // user claim reward
    function claimReward(uint256 round) external returns (uint256 reward);

    // ?? reward status
    // ?? function rewardReserved() external view returns (uint256);
    // ?? function rewardClaimed() external view returns (uint256);
    // ?? function reward(uint256 round) external view returns (uint256);

    // ?? prepare reward
    // ?? function prepareRewardIfNeeded(uint256 round) external;
    // ?? function isRewardPrepared(uint256 round) external view returns (bool);

    // ?? reward accounts
    // ?? function rewardAccountsCount(uint256 round) external view returns (uint256);
    // ?? functioin rewardAccountsAtIndex(uint256 round, uint256 index)  external view returns(address);
}
