// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
interface ILOVE20ExtensionCenter {
    // ------ structs ------
    struct ExtensionInfo {
        address tokenAddress;
        uint256 actionId;
    }

    // ------ events ------
    event ExtensionFactoryAdded(
        address indexed tokenAddress,
        address indexed factory
    );
    event ExtensionInitialized(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed extension
    );
    event AccountAdded(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed account
    );
    event AccountRemoved(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed account
    );

    // ------ errors ------
    error InvalidSubmitAddress();
    error InvalidJoinAddress();
    error NotEnoughGovVotes();
    error InvalidExtensionFactory();
    error ExtensionNotFoundInFactory();
    error InvalidWhiteListAddress();
    error ExtensionNotJoinedAction();
    error ExtensionFactoryAlreadyExists();
    error ExtensionAlreadyExists();
    error ExtensionNotFound();
    error OnlyExtensionCanCall();
    error AccountAlreadyJoined();
    error AccountNotJoined();
    error InitializeFailed();

    // ------ constructor ------
    function submitAddress() external view returns (address);
    function joinAddress() external view returns (address);

    // ------ register extension factory ------

    // only 0.3% gov votes holder can call once per round
    function addExtensionFactory(
        address tokenAddress,
        address factory
    ) external;

    // ------ all the extensions that successfully joined actions ------

    // will call extension's initialize() to  join the action, sucess: add extension to Center
    function initializeExtension(address extension) external;

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
    ) external;

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external;

    // ------ the accounts that joined the actions by extension
    function isAccountJoined(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool);

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
