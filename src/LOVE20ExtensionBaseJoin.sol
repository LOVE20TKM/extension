// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionReward} from "./base/ExtensionReward.sol";
import {Join} from "./base/Join.sol";
import {ILOVE20ExtensionJoin} from "./interface/ILOVE20ExtensionJoin.sol";

/// @title LOVE20ExtensionBaseJoin
/// @notice Abstract base contract for token-free join LOVE20 extensions
/// @dev Combines Join with LOVE20Extension functionality
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete join implementation with:
/// - Join without tokens to participate
/// - Withdraw at any time
/// - Integration with LOVE20 extension system
///
/// To implement this contract, you need to:
///
/// Implement joinedValue calculations from ILOVE20Extension
///    - isJoinedValueCalculated() - whether joined value is calculated
///    - joinedValue() - get total joined value
///    - joinedValueByAccount() - get joined value for specific account
///
abstract contract LOVE20ExtensionBaseJoin is
    ExtensionReward,
    Join,
    ILOVE20ExtensionJoin
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the join extension
    /// @param factory_ The factory address
    /// @param tokenAddress_ The token address
    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionReward(factory_, tokenAddress_) {}
}
