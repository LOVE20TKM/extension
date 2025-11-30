// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionTokenJoin} from "./ILOVE20ExtensionTokenJoin.sol";
import {IAutoScore} from "./base/IAutoScore.sol";

/// @title ILOVE20ExtensionTokenJoinAuto
/// @notice Interface for auto score-based token join LOVE20 extensions
/// @dev Combines token join with auto score calculation functionality
interface ILOVE20ExtensionTokenJoinAuto is ILOVE20ExtensionTokenJoin, IAutoScore {
    // All token join functionality is inherited from ILOVE20ExtensionTokenJoin
    // All auto score functionality is inherited from IAutoScore
}
