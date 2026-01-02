// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionCore {
    error AlreadyInitialized();
    error InvalidTokenAddress();
    error ActionIdNotFound();
    error MultipleActionIdsFound();
    error RoundNotFinished();

    function initializeIfNeeded() external;
    function initialized() external view returns (bool);

    function center() external view returns (address);
    function factory() external view returns (address);

    function tokenAddress() external view returns (address);
    function actionId() external view returns (uint256);

    function isJoinedValueConverted() external view returns (bool);
    function joinedValue() external view returns (uint256);
    function joinedValueByAccount(
        address account
    ) external view returns (uint256);
}
