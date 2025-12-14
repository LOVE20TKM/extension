// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExit} from "./IExit.sol";

/// @title ITokenJoin
/// @notice Interface for token-based join functionality
/// @dev Defines join/withdraw operations with ERC20 token-based participation and block-delayed withdrawal
interface ITokenJoin is IExit {
    // ============================================
    // ERRORS
    // ============================================

    /// @notice Thrown when join token address is invalid (zero address)
    error InvalidJoinTokenAddress();

    /// @notice Thrown when trying to join with zero amount
    error JoinAmountZero();

    /// @notice Thrown when account has no joined amount
    error NoJoinedAmount();

    /// @notice Thrown when trying to exit before waiting period ends
    error NotEnoughWaitingBlocks();

    // ============================================
    // EVENTS
    // ============================================

    /// @notice Emitted when an account joins
    /// @param tokenAddress The token address this extension is associated with
    /// @param round The current round
    /// @param actionId The action ID this extension is associated with
    /// @param account The account that joined
    /// @param amount The amount of tokens joined
    /// @param joinedBlock The block number when the join occurred
    event Join(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount,
        uint256 joinedBlock
    );

    /// @notice Emitted when an account exits
    /// @param tokenAddress The token address this extension is associated with
    /// @param round The current round
    /// @param actionId The action ID this extension is associated with
    /// @param account The account that exited
    /// @param amount The amount of tokens withdrawn
    event Exit(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get the token address that can be joined
    /// @return The join token address
    function joinTokenAddress() external view returns (address);

    /// @notice Get the number of blocks to wait before exit
    /// @return The waiting period in blocks
    function waitingBlocks() external view returns (uint256);

    /// @notice Get the total amount of tokens joined by all accounts
    /// @return The total joined amount
    function totalJoinedAmount() external view returns (uint256);

    /// @notice Get the total joined amount at a specific round
    /// @param round The round to query
    /// @return The total joined amount at the round
    function totalJoinedAmountByRound(
        uint256 round
    ) external view returns (uint256);

    /// @notice Get the joined amount for an account at a specific round
    /// @param account The account address to query
    /// @param round The round to query
    /// @return The joined amount at the round
    function amountByAccountByRound(
        address account,
        uint256 round
    ) external view returns (uint256);

    /// @notice Get join information for a specific account
    /// @param account The account address to query
    /// @return joinedRound The round when the join occurred
    /// @return amount The amount of tokens joined
    /// @return joinedBlock The block number when the join occurred
    /// @return exitableBlock The block number when exit becomes available
    function joinInfo(
        address account
    )
        external
        view
        returns (
            uint256 joinedRound,
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        );

    // ============================================
    // STATE-CHANGING FUNCTIONS
    // ============================================

    /// @notice Join with tokens to participate in the extension
    /// @param amount The amount of tokens to join with
    /// @param verificationInfos Optional verification information array
    function join(uint256 amount, string[] memory verificationInfos) external;
}
