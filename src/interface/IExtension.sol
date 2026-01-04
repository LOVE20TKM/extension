// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtension {
    error AlreadyInitialized();
    error InvalidTokenAddress();
    error ActionIdNotFound();
    error MultipleActionIdsFound();
    error RoundNotFinished();

    function CENTER_ADDRESS() external view returns (address);
    function FACTORY_ADDRESS() external view returns (address);
    function TOKEN_ADDRESS() external view returns (address);

    function initializeIfNeeded() external;
    function initialized() external view returns (bool);

    function actionId() external view returns (uint256);

    function isJoinedValueConverted() external view returns (bool);
    function joinedValue() external view returns (uint256);
    function joinedValueByAccount(
        address account
    ) external view returns (uint256);
}
