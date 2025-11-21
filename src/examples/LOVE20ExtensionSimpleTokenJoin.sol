// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    LOVE20ExtensionBaseTokenJoin
} from "../LOVE20ExtensionBaseTokenJoin.sol";
import {ExtensionReward} from "../base/ExtensionReward.sol";
import {IExtensionReward} from "../interface/base/IExtensionReward.sol";

/// @title LOVE20ExtensionSimpleTokenJoin
/// @notice Example implementation of LOVE20ExtensionBaseTokenJoin
/// @dev Simple implementation where joined value equals joined amount
contract LOVE20ExtensionSimpleTokenJoin is LOVE20ExtensionBaseTokenJoin {
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the simple token join extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoin(
            factory_,
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

    /// @notice Get reward information for an account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return reward The reward amount (0 for this simple implementation)
    /// @return isMinted Whether the reward has been minted
    function rewardByAccount(
        uint256 round,
        address account
    )
        public
        view
        virtual
        override(ExtensionReward, IExtensionReward)
        returns (uint256 reward, bool isMinted)
    {
        // Simple implementation returns 0 reward
        // In a real implementation, this would calculate rewards based on joined amounts
        return (0, false);
    }
}
