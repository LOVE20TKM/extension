// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20Extension {
    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when a user claims a reward
    event ClaimReward(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 round,
        uint256 reward
    );

    /// @notice Emitted when verification info is updated
    event UpdateVerificationInfo(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        string verificationKey,
        uint256 round,
        string verificationInfo
    );

    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when a function is called by non-center address
    error OnlyCenterCanCall();

    /// @notice Thrown when trying to initialize an already initialized extension
    error AlreadyInitialized();

    /// @notice Thrown when an invalid token address is provided
    error InvalidTokenAddress();

    /// @notice Thrown when a reward has already been claimed for a round
    error AlreadyClaimed();

    /// @notice Thrown when a round is not finished
    error RoundNotFinished();

    /// @notice Thrown when verification keys and values length mismatch
    error VerificationInfoLengthMismatch();

    // ============================================
    // FUNCTIONS
    // ============================================

    // constructor params
    function center() external view returns (address);
    function factory() external view returns (address);
    function tokenAddress() external returns (address);
    function actionId() external returns (uint256);

    // join action as the only whitelist address, only Center can call
    function initialize(address tokenAddress, uint256 actionId) external;

    // ------ user operation ------
    // join&remove action shuold be implemented in the extension with different input params

    // ------ joined value status ------
    // calculated based on tokenAddress token units directly or indirectly participated
    function isJoinedValueCalculated() external view returns (bool);
    function joinedValue() external view returns (uint256);
    function joinedValueByAccount(
        address account
    ) external view returns (uint256);

    // ------ account status ------
    function accounts() external view returns (address[] memory);
    function accountsCount() external view returns (uint256);
    function accountAtIndex(uint256) external view returns (address);

    // ------ reward ------
    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted);
    // user claim reward
    function claimReward(uint256 round) external returns (uint256 reward);

    // ------ verification info ------
    /// @notice Update verification information for the caller
    /// @dev verificationKeys are automatically retrieved from action's verificationKeys
    /// @param verificationInfos Array of verification information corresponding to action's verificationKeys
    function updateVerificationInfo(string[] memory verificationInfos) external;

    /// @notice Get the latest verification info for an account and key
    /// @param account The account address
    /// @param verificationKey The verification key
    /// @return The latest verification info
    function verificationInfo(
        address account,
        string calldata verificationKey
    ) external view returns (string memory);

    /// @notice Get verification info for a specific round
    /// @param account The account address
    /// @param verificationKey The verification key
    /// @param round The round number
    /// @return The verification info at or before the specified round
    function verificationInfoByRound(
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view returns (string memory);

    /// @notice Get the count of rounds when verification info was updated
    /// @param account The account address
    /// @param verificationKey The verification key
    /// @return The count of update rounds
    function verificationInfoUpdateRoundsCount(
        address account,
        string calldata verificationKey
    ) external view returns (uint256);

    /// @notice Get a specific round when verification info was updated
    /// @param account The account address
    /// @param verificationKey The verification key
    /// @param index The index in the update rounds array
    /// @return The round number
    function verificationInfoUpdateRoundsAtIndex(
        address account,
        string calldata verificationKey,
        uint256 index
    ) external view returns (uint256);
}
