// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
interface IExtensionCenter {
    // ------ events ------
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
    event UpdateVerificationInfo(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        string verificationKey,
        string verificationInfo
    );
    event ExtensionDelegateSet(
        address indexed extension,
        address indexed delegate
    );

    // ------ errors ------
    error InvalidUniswapV2FactoryAddress();
    error InvalidLaunchAddress();
    error InvalidStakeAddress();
    error InvalidSubmitAddress();
    error InvalidVoteAddress();
    error InvalidJoinAddress();
    error InvalidVerifyAddress();
    error InvalidMintAddress();
    error InvalidRandomAddress();
    error OnlyExtensionCanCall();
    error AccountAlreadyJoined();
    error VerificationInfoLengthMismatch();
    error ActionNotVotedInCurrentRound();
    error InvalidExtensionFactory();
    error ExtensionNotFoundInFactory();

    // ------ core system addresses ------
    function uniswapV2FactoryAddress() external view returns (address);
    function launchAddress() external view returns (address);
    function stakeAddress() external view returns (address);
    function submitAddress() external view returns (address);
    function voteAddress() external view returns (address);
    function joinAddress() external view returns (address);
    function verifyAddress() external view returns (address);
    function mintAddress() external view returns (address);
    function randomAddress() external view returns (address);

    // ------ extension query ------
    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    function extensionByActionId(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    function factoryByActionId(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    // ------ extension delegate management ------
    /// @notice Set delegate contract for the calling extension
    /// @dev Only the extension itself can set its delegate
    /// @param delegate The delegate contract address (address(0) to remove delegate)
    function setExtensionDelegate(address delegate) external;

    /// @notice Get delegate contract for an extension
    /// @param extensionAddress The extension address
    /// @return The delegate contract address (address(0) if not set)
    function extensionDelegate(
        address extensionAddress
    ) external view returns (address);

    // ------ only the corresponding action extension can call ------
    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external;

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external;

    function forceExit(address tokenAddress, uint256 actionId) external;

    // ------ the accounts that joined the actions by extension
    function isAccountJoined(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool);

    function actionIdsByAccount(
        address tokenAddress,
        address account,
        address[] calldata factories
    )
        external
        view
        returns (
            uint256[] memory actionIds,
            address[] memory extensions,
            address[] memory factories_
        );

    // ------ the accounts that joined the actions by extension (action dimension)
    function accounts(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address[] memory);

    function accountsCount(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256);

    function accountsAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) external view returns (address);

    // ------ the accounts that joined the actions by extension (by round)
    function accountsByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (address[] memory);

    function accountsByRoundCount(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (uint256);

    function accountsByRoundAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index,
        uint256 round
    ) external view returns (address);

    // ------ verification info ------
    function updateVerificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external;

    function verificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string calldata verificationKey
    ) external view returns (string memory);

    function verificationInfoByRound(
        address tokenAddress,
        uint256 actionId,
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view returns (string memory);
}
