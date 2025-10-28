// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface ILOVE20Extension {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when a function is called by non-center address
    error OnlyCenterCanCall();

    /// @notice Thrown when trying to initialize an already initialized extension
    error AlreadyInitialized();

    /// @notice Thrown when an invalid token address is provided
    error InvalidTokenAddress();

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
}
