// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20ExtensionJoinable {
    // Center required functions
    // join action as the only whitelist address
    function initialize() external;
    function requestRemove(address account) external returns (bool);
    function factory() external view returns (address);

    // joined action
    function tokenAddress() external returns (address);
    function actionId() external returns (uint256);
    function initialized() external returns (bool);

    // joined status
    function isJoined(address account) external view returns (bool);
    function accountsCount() external view returns (uint256);
    function accountAtIndex(uint256) external view returns (address);

    // reward prepared
    function rewardReserved() external view returns (uint256);
    function rewardClaimed() external view returns (uint256);
    function reward(uint256 round) external view returns (uint256);

    // reward
    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted);
    function claimReward(uint256 round) external returns (uint256 reward);

    // ?? prepare reward
    // ?? function prepareRewardIfNeeded(uint256 round) external;
    // ?? function isRewardPrepared(uint256 round) external view returns (bool);

    // ?? reward accounts
    // ?? function rewardAccountsCount(uint256 round) external view returns (uint256);
    // ?? functioin rewardAccountsAtIndex(uint256 round, uint256 index)  external view returns(address);
}
