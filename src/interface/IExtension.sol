// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionEvents {
    event Initialize(address indexed tokenAddress, uint256 indexed actionId);
}

interface IExtensionErrors {
    error AlreadyInitialized();
    error InvalidTokenAddress();
    error ActionIdNotFound();
    error MultipleActionIdsFound();
    error RoundNotFinished(uint256 currentRound);
}

interface IExtension is IExtensionEvents, IExtensionErrors {
    function FACTORY_ADDRESS() external view returns (address);
    function TOKEN_ADDRESS() external view returns (address);

    function initializeIfNeeded() external;
    function initialized() external view returns (bool);

    function actionId() external view returns (uint256);

    function joinedAmount() external view returns (uint256);
    function joinedAmountByAccount(
        address account
    ) external view returns (uint256);
    function joinedAmountTokenAddress() external view returns (address);
}
