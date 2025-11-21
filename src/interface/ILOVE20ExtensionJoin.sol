// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Extension} from "./ILOVE20Extension.sol";
import {IJoin} from "./base/IJoin.sol";

/// @title ILOVE20ExtensionJoin
/// @notice Interface for base join LOVE20 extensions
/// @dev Combines LOVE20Extension with token-free join/withdraw mechanisms
interface ILOVE20ExtensionJoin is ILOVE20Extension, IJoin {
    // All join-related functionality is inherited from IJoin
    // All extension-related functionality is inherited from ILOVE20Extension
}

