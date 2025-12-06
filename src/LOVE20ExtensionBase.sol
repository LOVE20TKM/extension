// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionAccounts} from "./base/ExtensionAccounts.sol";
import {VerificationInfo} from "./base/VerificationInfo.sol";
import {ExtensionReward} from "./base/ExtensionReward.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";

/// @title LOVE20ExtensionBase
/// @notice Abstract base contract for LOVE20 extensions
/// @dev Provides common storage and implementation for all extensions
abstract contract LOVE20ExtensionBase is
    ExtensionAccounts,
    VerificationInfo,
    ExtensionReward,
    ILOVE20Extension
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param tokenAddress_ The token address
    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionReward(factory_, tokenAddress_) {}
}
