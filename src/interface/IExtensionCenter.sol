// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

struct TokenActionPair {
    address tokenAddress;
    uint256 actionId;
}

interface IExtensionCenter {
    event AddAccount(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed account
    );
    event RemoveAccount(
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
    event BindAction(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed extension,
        address factory
    );

    error InvalidUniswapV2FactoryAddress();
    error InvalidLaunchAddress();
    error InvalidStakeAddress();
    error InvalidSubmitAddress();
    error InvalidVoteAddress();
    error InvalidJoinAddress();
    error InvalidVerifyAddress();
    error InvalidMintAddress();
    error InvalidRandomAddress();
    error OnlyExtensionOrDelegate();
    error OnlyUserOrExtensionOrDelegate();
    error AccountAlreadyJoined();
    error VerificationInfoLengthMismatch();
    error ActionNotVotedInCurrentRound();
    error ExtensionNotFoundInFactory();
    error ActionAlreadyBoundToOtherAction();

    function uniswapV2FactoryAddress() external view returns (address);
    function launchAddress() external view returns (address);
    function stakeAddress() external view returns (address);
    function submitAddress() external view returns (address);
    function voteAddress() external view returns (address);
    function joinAddress() external view returns (address);
    function verifyAddress() external view returns (address);
    function mintAddress() external view returns (address);
    function randomAddress() external view returns (address);

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

    function forceRemove(address tokenAddress, uint256 actionId) external;

    function updateVerificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external;

    function setExtensionDelegate(address delegate) external;

    function registerActionIfNeeded(
        address tokenAddress,
        uint256 actionId
    ) external returns (address extensionAddress);

    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    function factory(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address);

    function extensionDelegate(
        address extensionAddress
    ) external view returns (address);

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
