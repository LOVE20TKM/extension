// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
interface ILOVE20ExtensionCenter {
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
    function exists(address extension) external view returns (bool);
    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    function extensionsCount(
        address tokenAddress
    ) external view returns (uint256);
    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address);
    function extensionInfo(
        address extension
    )
        external
        view
        returns (address manager, address tokenAddress, uint256 actionId);

    // ------ the accounts that joined the actions by extension
    // only extension can call
    function actionAddAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external returns (bool);
    function actionRemoveAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external returns (bool);

    // Users can remove themselves from an action or managed by the action's extension
    function actionRequestRemove(
        address tokenAddress,
        uint256 actionId
    ) external returns (bool);
    // only 1 of 3 status is true
    function actionAccountStatus(
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
