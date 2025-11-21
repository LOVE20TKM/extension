// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Extension} from "./ILOVE20Extension.sol";
import {ITokenJoin} from "./base/ITokenJoin.sol";

/// @title ILOVE20ExtensionTokenJoin
/// @notice Interface for base token join LOVE20 extensions
/// @dev Combines LOVE20Extension with token-based join/withdraw mechanisms
interface ILOVE20ExtensionTokenJoin is ILOVE20Extension, ITokenJoin {
    // All join-related functionality is inherited from ITokenJoin
    // All extension-related functionality is inherited from ILOVE20Extension
}

