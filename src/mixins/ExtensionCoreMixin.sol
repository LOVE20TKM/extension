// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Extension} from "../interface/ILOVE20Extension.sol";
import {
    ILOVE20ExtensionFactory,
    DEFAULT_JOIN_AMOUNT
} from "../interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";
import {ILOVE20Launch} from "@core/interfaces/ILOVE20Launch.sol";
import {ILOVE20Stake} from "@core/interfaces/ILOVE20Stake.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/interfaces/ILOVE20Mint.sol";
import {ILOVE20Random} from "@core/interfaces/ILOVE20Random.sol";
import {IExtensionCore} from "../interface/base/IExtensionCore.sol";

/// @title ExtensionCoreMixin
/// @notice Core mixin providing fundamental extension functionality
/// @dev Provides factory/center references, protocol interfaces, and basic initialization
///
/// **Features:**
/// - Factory and center contract references
/// - Protocol contract interfaces (Launch, Stake, Submit, Vote, Join, Verify, Mint, Random)
/// - Basic initialization
/// - Access control (onlyCenter modifier)
///
abstract contract ExtensionCoreMixin {
    // ============================================
    // ERRORS
    // ============================================
    error AlreadyInitialized();
    error InvalidTokenAddress();
    error ActionIdNotFound();
    error MultipleActionIdsFound();

    // ============================================
    // STATE VARIABLES
    // ============================================

    address public immutable factory;
    ILOVE20ExtensionCenter internal immutable _center;
    address public tokenAddress;
    uint256 public actionId;
    bool public initialized;

    ILOVE20Launch internal immutable _launch;
    ILOVE20Stake internal immutable _stake;
    ILOVE20Submit internal immutable _submit;
    ILOVE20Vote internal immutable _vote;
    ILOVE20Join internal immutable _join;
    ILOVE20Verify internal immutable _verify;
    ILOVE20Mint internal immutable _mint;
    ILOVE20Random internal _random;

    constructor(address factory_, address tokenAddress_) {
        if (tokenAddress_ == address(0)) {
            revert InvalidTokenAddress();
        }
        factory = factory_;
        tokenAddress = tokenAddress_;
        _center = ILOVE20ExtensionCenter(
            ILOVE20ExtensionFactory(factory_).center()
        );
        _launch = ILOVE20Launch(_center.launchAddress());
        _stake = ILOVE20Stake(_center.stakeAddress());
        _submit = ILOVE20Submit(_center.submitAddress());
        _vote = ILOVE20Vote(_center.voteAddress());
        _join = ILOVE20Join(_center.joinAddress());
        _verify = ILOVE20Verify(_center.verifyAddress());
        _mint = ILOVE20Mint(_center.mintAddress());
        _random = ILOVE20Random(_center.randomAddress());
    }

    function center() public view returns (address) {
        return address(_center);
    }

    /// @dev Core initialization logic
    function _doInitialize(uint256 actionId_) internal {
        if (initialized) {
            revert AlreadyInitialized();
        }

        initialized = true;
        actionId = actionId_;

        ILOVE20Token token = ILOVE20Token(tokenAddress);
        token.approve(address(_join), DEFAULT_JOIN_AMOUNT);
        _join.join(
            tokenAddress,
            actionId,
            DEFAULT_JOIN_AMOUNT,
            new string[](0)
        );

        // Register to center
        _center.registerExtension();
    }

    /// @dev Auto-initialize by scanning voted actions to find matching actionId
    function _autoInitialize() internal {
        if (initialized) {
            return;
        }

        // Get current round from join phase (action phase)
        uint256 currentRound = _join.currentRound();
        uint256 count = _vote.votedActionIdsCount(tokenAddress, currentRound);
        uint256 foundActionId = 0;
        bool found = false;

        for (uint256 i = 0; i < count; i++) {
            uint256 aid = _vote.votedActionIdsAtIndex(
                tokenAddress,
                currentRound,
                i
            );
            ActionInfo memory info = _submit.actionInfo(tokenAddress, aid);
            if (info.body.whiteListAddress == address(this)) {
                if (found) revert MultipleActionIdsFound();
                foundActionId = aid;
                found = true;
            }
        }
        if (!found) revert ActionIdNotFound();

        _doInitialize(foundActionId);
    }
}
