// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    LOVE20ExtensionBaseTokenJoin
} from "../LOVE20ExtensionBaseTokenJoin.sol";
import {ExtensionReward} from "../base/ExtensionReward.sol";
import {IExtensionReward} from "../interface/base/IExtensionReward.sol";

/// @title ExampleTokenJoin
/// @notice Example implementation of LOVE20ExtensionBaseTokenJoin
/// @dev Simple implementation where joined value equals joined amount
contract ExampleTokenJoin is LOVE20ExtensionBaseTokenJoin {
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the example token join extension
    /// @param factory_ The factory address
    /// @param tokenAddress_ The token address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoin(
            factory_,
            tokenAddress_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    // ============================================
    // JOINED VALUE CALCULATION - REQUIRED IMPLEMENTATION
    // ============================================

    /// @notice Check if joined value is calculated (always true for this implementation)
    /// @return Always returns true
    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    /// @notice Get the total joined value
    /// @dev Returns the total amount of tokens joined by all accounts
    /// @return The total joined value
    function joinedValue() external view override returns (uint256) {
        return totalJoinedAmount;
    }

    /// @notice Get the joined value for a specific account
    /// @param account The account address to query
    /// @return The joined value for the account
    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        return _joinInfo[account].amount;
    }

    // ============================================
    // REWARD CALCULATION - REQUIRED IMPLEMENTATION
    // ============================================

    /// @dev Calculate reward for an account in a specific round
    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual override returns (uint256 reward) {
        (uint256 totalActionReward, ) = _mint.actionRewardByActionIdByAccount(
            tokenAddress,
            round,
            actionId,
            address(this)
        );

        reward =
            (totalActionReward * _joinInfo[account].amount) /
            totalJoinedAmount;
        return reward;
    }
}
