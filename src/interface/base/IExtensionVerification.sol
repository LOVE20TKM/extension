// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IExtensionVerification {
    // ============================================
    // EVENTS
    // ============================================

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

    /// @notice Thrown when verification keys and values length mismatch
    error VerificationInfoLengthMismatch();

    // ============================================
    // FUNCTIONS - Verification Info
    // ============================================

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

