// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionBase} from "./LOVE20ExtensionBase.sol";
import {TokenJoin} from "./base/TokenJoin.sol";
import {
    ILOVE20ExtensionTokenJoin
} from "./interface/ILOVE20ExtensionTokenJoin.sol";

/// @title LOVE20ExtensionTokenJoinBase
/// @notice Abstract base contract for token join LOVE20 extensions
/// @dev Combines TokenJoin with LOVE20Extension functionality
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete join implementation with:
/// - Join with tokens to participate
/// - Withdraw after block-based waiting period
/// - Integration with LOVE20 extension system
///
/// To implement this contract, you need to:
///
/// Implement joinedValue calculations from ILOVE20Extension
///    - isJoinedValueCalculated() - whether joined value is calculated
///    - joinedValue() - get total joined value
///    - joinedValueByAccount() - get joined value for specific account
///
abstract contract LOVE20ExtensionTokenJoinBase is
    LOVE20ExtensionBase,
    TokenJoin,
    ILOVE20ExtensionTokenJoin
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the token join extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBase(factory_)
        TokenJoin(joinTokenAddress_, waitingBlocks_)
    {
        // LOVE20ExtensionBase handles ExtensionCore initialization with factory_
        // TokenJoin handles join-specific initialization
    }
}
