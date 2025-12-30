// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtension {
    event ClaimReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    error AlreadyInitialized();
    error InvalidTokenAddress();
    error ActionIdNotFound();
    error MultipleActionIdsFound();
    error AlreadyClaimed();
    error RoundNotFinished();

    function initializeAction() external;
    function initialized() external view returns (bool);

    function center() external view returns (address);
    function factory() external view returns (address);

    function tokenAddress() external view returns (address);
    function actionId() external view returns (uint256);

    function isJoinedValueCalculated() external view returns (bool);
    function joinedValue() external view returns (uint256);
    function joinedValueByAccount(
        address account
    ) external view returns (uint256);

    function reward(uint256 round) external view returns (uint256);
    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted);

    function claimReward(uint256 round) external returns (uint256 reward);
}
