// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionAutoScore} from "./LOVE20ExtensionAutoScore.sol";
import {TokenJoin} from "./base/TokenJoin.sol";
import {
    ILOVE20ExtensionAutoScoreJoin
} from "./interface/ILOVE20ExtensionAutoScoreJoin.sol";
import {ITokenJoin} from "./interface/base/ITokenJoin.sol";

/// @title LOVE20ExtensionAutoScoreJoin
/// @notice Abstract base contract for auto-score-based join LOVE20 extensions
/// @dev Combines TokenJoin with auto-score functionality, adding verification result preparation
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete join implementation with:
/// - Join with tokens to participate
/// - Withdraw after block-based waiting period
/// - Auto score calculation integrated with join amounts
///
/// To implement this contract, you need to:
///
/// Implement calculateScores() and calculateScore() from LOVE20ExtensionAutoScore
///    - Define how scores are calculated based on joined amounts
///    - See LOVE20ExtensionAutoScore for details
///
abstract contract LOVE20ExtensionAutoScoreJoin is
    LOVE20ExtensionAutoScore,
    TokenJoin,
    ILOVE20ExtensionAutoScoreJoin
{
    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the join extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionAutoScore(factory_)
        TokenJoin(joinTokenAddress_, waitingBlocks_)
    {
        // LOVE20ExtensionAutoScore handles ExtensionCore initialization with factory_
        // TokenJoin handles join-specific initialization
    }

    // ============================================
    // USER OPERATIONS - OVERRIDE WITH VERIFICATION
    // ============================================

    /// @inheritdoc ITokenJoin
    /// @dev Override to add verification result preparation before join
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual override(ITokenJoin, TokenJoin) {
        _prepareVerifyResultIfNeeded();
        super.join(amount, verificationInfos);
    }

    /// @inheritdoc ITokenJoin
    /// @dev Override to add verification result preparation before withdraw
    function withdraw() public virtual override(ITokenJoin, TokenJoin) {
        _prepareVerifyResultIfNeeded();
        super.withdraw();
    }
}
