// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionAutoScore} from "./ILOVE20ExtensionAutoScore.sol";
import {ITokenJoin} from "./base/ITokenJoin.sol";

/// @title ILOVE20ExtensionAutoScoreJoin
/// @notice Interface for auto-score-based extensions with token join functionality
/// @dev Combines auto score calculation with token-based join/withdraw mechanisms
interface ILOVE20ExtensionAutoScoreJoin is
    ILOVE20ExtensionAutoScore,
    ITokenJoin
{
    // All join-related functionality is inherited from ITokenJoin
    // All score-related functionality is inherited from ILOVE20ExtensionAutoScore
}
