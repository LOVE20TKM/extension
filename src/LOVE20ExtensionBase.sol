// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "./interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";
import {ILOVE20ExtensionFactory} from "./interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20Token} from "@love20/interfaces/ILOVE20Token.sol";
import {ILOVE20Join} from "@love20/interfaces/ILOVE20Join.sol";

uint256 constant DEFAULT_JOIN_AMOUNT = 1000000000000000000; // 1 token

/// @title LOVE20ExtensionBase
/// @notice Abstract base contract for LOVE20 extensions
/// @dev Provides common storage and implementation for all extensions
abstract contract LOVE20ExtensionBase is ILOVE20Extension {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The factory contract address
    address public immutable factory;

    /// @notice The token address this extension is associated with
    address public tokenAddress;

    /// @notice The action ID this extension is associated with
    uint256 public actionId;

    /// @notice Whether the extension has been initialized
    bool public initialized;

    /// @dev Array of accounts participating in this extension
    address[] internal _accounts;

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
    }

    // ============================================
    // ILOVE20Extension INTERFACE - BASIC INFO
    // ============================================

    /// @inheritdoc ILOVE20Extension
    function center() external view returns (address) {
        return ILOVE20ExtensionFactory(factory).center();
    }

    // ============================================
    // ILOVE20Extension INTERFACE - ACCOUNT MANAGEMENT
    // ============================================

    /// @inheritdoc ILOVE20Extension
    function accounts() external view returns (address[] memory) {
        return _accounts;
    }

    /// @inheritdoc ILOVE20Extension
    function accountsCount() external view returns (uint256) {
        return _accounts.length;
    }

    /// @inheritdoc ILOVE20Extension
    function accountAtIndex(uint256 index) external view returns (address) {
        return _accounts[index];
    }

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @inheritdoc ILOVE20Extension
    /// @dev Base implementation handles common validation and state updates
    /// Subclasses should override _afterInitialize() for custom logic
    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) external onlyCenter {
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
        ILOVE20Join join = ILOVE20Join(
            ILOVE20ExtensionCenter(ILOVE20ExtensionFactory(factory).center())
                .joinAddress()
        );
        token.approve(address(join), DEFAULT_JOIN_AMOUNT);

        // Join the action
        join.join(tokenAddress, actionId, DEFAULT_JOIN_AMOUNT, new string[](0));

        // Call hook for subclass-specific initialization
        _afterInitialize();
    }

    /// @dev Hook called after base initialization is complete
    /// Subclasses should override this to add custom initialization logic
    function _afterInitialize() internal virtual {}

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Add an account to the internal accounts array
    /// @param account The account address to add
    function _addAccount(address account) internal {
        _accounts.push(account);
    }

    /// @dev Remove an account from the internal accounts array
    /// @param account The account address to remove
    function _removeAccount(address account) internal {
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (_accounts[i] == account) {
                _accounts[i] = _accounts[_accounts.length - 1];
                _accounts.pop();
                break;
            }
        }
    }
}
