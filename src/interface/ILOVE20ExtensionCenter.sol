// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
interface ILOVE20ExtensionCenter {
    // ------ constructor ------
    function joinAddress() external view returns (address);

    // ------ register extension factory ------

    // only 0.3% gov votes holder can call once per round
    function addExtensionFactory(address factory) external;

    // ------ all the extensions that successfully joined actions ------

    // will call extension's initialize() to  join the action, sucess: add extension to Center
    function initializeExtension(
        address tokenAddress,
        uint256 actionId,
        address extension
    ) external;

    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    function extensionInfo(
        address extension
    ) external view returns (address tokenAddress, uint256 actionId);

    function extensionsCount(
        address tokenAddress
    ) external view returns (uint256);

    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address);

    // ------ only the corresponding action extension can call ------
    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external returns (bool);

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external returns (bool);

    // ------ the accounts that joined the actions by extension
    // only 1 of 3 status is true
    function accountStatus(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool added, bool requestRemove, bool removed);

    function actionIdsByAccount(
        address tokenAddress,
        address account
    ) external view returns (uint256[] memory);

    function actionIdsByAccountCount(
        address tokenAddress,
        address account
    ) external view returns (uint256);

    function actionIdsByAccountAtIndex(
        address tokenAddress,
        address account,
        uint256 index
    ) external view returns (uint256);
}
