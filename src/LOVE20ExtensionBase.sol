// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./base/ExtensionCore.sol";
import {ExtensionAccounts} from "./base/ExtensionAccounts.sol";
import {ExtensionVerificationInfo} from "./base/ExtensionVerificationInfo.sol";
import {ExtensionReward} from "./base/ExtensionReward.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";

/// @title LOVE20ExtensionBase
/// @notice Abstract base contract for LOVE20 extensions
/// @dev Provides common storage and implementation for all extensions
abstract contract LOVE20ExtensionBase is
    ExtensionCore,
    ExtensionAccounts,
    ExtensionVerificationInfo,
    ExtensionReward,
    ILOVE20Extension
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    constructor(address factory_) ExtensionCore(factory_) {}
}
