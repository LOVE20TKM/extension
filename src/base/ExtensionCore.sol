// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";
import {
    IExtensionCore,
    DEFAULT_JOIN_AMOUNT
} from "../interface/base/IExtensionCore.sol";
import {
    ILOVE20ExtensionFactory
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

/// @title ExtensionCore
/// @notice Core base contract providing fundamental extension functionality
/// @dev Implements IExtensionCore interface with factory/center references and initialization
abstract contract ExtensionCore is IExtensionCore {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The factory contract address
    address public immutable factory;

    /// @notice The center contract address
    ILOVE20ExtensionCenter internal immutable _center;

    /// @notice The token address this extension is associated with
    address public tokenAddress;

    /// @notice Whether the extension has been initialized
    bool public initialized;

    /// @notice The action ID this extension is associated with
    uint256 public actionId;

    /// @notice The launch contract address
    ILOVE20Launch internal immutable _launch;
    /// @notice The stake contract address
    ILOVE20Stake internal immutable _stake;
    /// @notice The submit contract address
    ILOVE20Submit internal immutable _submit;
    /// @notice The vote contract address
    ILOVE20Vote internal immutable _vote;
    /// @notice The join contract address
    ILOVE20Join internal immutable _join;
    /// @notice The verify contract address
    ILOVE20Verify internal immutable _verify;
    /// @notice The mint contract address
    ILOVE20Mint internal immutable _mint;
    /// @notice The random contract address
    ILOVE20Random internal immutable _random;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param tokenAddress_ The token address (required, cannot be address(0))
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

    // ============================================
    // IEXTENSIONCORE INTERFACE
    // ============================================

    /// @inheritdoc IExtensionCore
    function center() public view returns (address) {
        return address(_center);
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================

    /// @dev Core initialization logic shared by initialize() and _autoInitialize()
    function _doInitialize(uint256 actionId_) internal {
        if (initialized) {
            revert AlreadyInitialized();
        }

        initialized = true;
        actionId = actionId_;

        // Approve token to joinAddress before joining
        ILOVE20Token token = ILOVE20Token(tokenAddress);
        token.approve(address(_join), DEFAULT_JOIN_AMOUNT);

        // Join the action
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
