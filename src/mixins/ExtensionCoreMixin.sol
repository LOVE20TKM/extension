// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Extension} from "../interface/ILOVE20Extension.sol";
import {
    ILOVE20ExtensionFactory
} from "../interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";
import {ILOVE20Launch} from "@core/interfaces/ILOVE20Launch.sol";
import {ILOVE20Stake} from "@core/interfaces/ILOVE20Stake.sol";
import {ILOVE20Submit} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/interfaces/ILOVE20Mint.sol";
import {ILOVE20Random} from "@core/interfaces/ILOVE20Random.sol";

uint256 constant DEFAULT_JOIN_AMOUNT = 1000000000000000000; // 1 token

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
    error OnlyCenterCanCall();
    error AlreadyInitialized();
    error InvalidTokenAddress();

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

    modifier onlyCenter() {
        if (msg.sender != address(_center)) {
            revert OnlyCenterCanCall();
        }
        _;
    }

    constructor(address factory_) {
        factory = factory_;
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

    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) public virtual onlyCenter {
        if (initialized) {
            revert AlreadyInitialized();
        }
        if (tokenAddress_ == address(0)) {
            revert InvalidTokenAddress();
        }

        initialized = true;
        tokenAddress = tokenAddress_;
        actionId = actionId_;

        ILOVE20Token token = ILOVE20Token(tokenAddress);
        token.approve(address(_join), DEFAULT_JOIN_AMOUNT);
        _join.join(
            tokenAddress,
            actionId,
            DEFAULT_JOIN_AMOUNT,
            new string[](0)
        );
    }
}
