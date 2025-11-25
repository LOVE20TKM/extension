// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "../interface/ILOVE20ExtensionCenter.sol";
import {IExtensionCore} from "../interface/base/IExtensionCore.sol";
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

/// @title ExtensionCore
/// @notice Core base contract providing fundamental extension functionality
/// @dev Implements IExtensionCore interface with factory/center references and initialization
abstract contract ExtensionCore is IExtensionCore {
    // ============================================
    // CONSTANTS
    // ============================================

    /// @notice Default amount of tokens to join with during initialization
    /// @dev Set to 1 token (1e18 wei)
    uint256 internal constant DEFAULT_JOIN_AMOUNT = 1e18;

    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The factory contract address
    address public immutable factory;

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
    // MODIFIERS
    // ============================================

    /// @dev Restricts function access to center contract only
    modifier onlyCenter() {
        if (msg.sender != ILOVE20ExtensionFactory(factory).center()) {
            revert OnlyCenterCanCall();
        }
        _;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    constructor(address factory_) {
        factory = factory_;
        ILOVE20ExtensionCenter c = ILOVE20ExtensionCenter(
            ILOVE20ExtensionFactory(factory_).center()
        );
        _launch = ILOVE20Launch(c.launchAddress());
        _stake = ILOVE20Stake(c.stakeAddress());
        _submit = ILOVE20Submit(c.submitAddress());
        _vote = ILOVE20Vote(c.voteAddress());
        _join = ILOVE20Join(c.joinAddress());
        _verify = ILOVE20Verify(c.verifyAddress());
        _mint = ILOVE20Mint(c.mintAddress());
        _random = ILOVE20Random(c.randomAddress());
    }

    // ============================================
    // IEXTENSIONCORE INTERFACE
    // ============================================

    /// @inheritdoc IExtensionCore
    function center() public view returns (address) {
        return ILOVE20ExtensionFactory(factory).center();
    }

    /// @inheritdoc IExtensionCore
    /// @dev Base implementation handles common validation and state updates
    /// Subclasses can override this function and call super.initialize() for custom logic
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
    }
}
