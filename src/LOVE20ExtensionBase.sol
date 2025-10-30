// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "./interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";
import {ILOVE20ExtensionFactory} from "./interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20Token} from "@love20/interfaces/ILOVE20Token.sol";
import {ILOVE20Launch} from "@love20/interfaces/ILOVE20Launch.sol";
import {ILOVE20Stake} from "@love20/interfaces/ILOVE20Stake.sol";
import {ILOVE20Submit} from "@love20/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@love20/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@love20/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@love20/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@love20/interfaces/ILOVE20Mint.sol";
import {ILOVE20Random} from "@love20/interfaces/ILOVE20Random.sol";

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
    ILOVE20Random internal _random;

    /// @dev Array of accounts participating in this extension
    address[] internal _accounts;

    /// @dev round => reward
    mapping(uint256 => uint256) internal _reward;

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
    // ILOVE20Extension INTERFACE - BASIC INFO
    // ============================================

    /// @inheritdoc ILOVE20Extension
    function center() public view returns (address) {
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

    /// @dev Add an account to the internal accounts array and center registry
    /// @param account The account address to add
    function _addAccount(address account) internal {
        _accounts.push(account);
        ILOVE20ExtensionCenter(center()).addAccount(
            tokenAddress,
            actionId,
            account
        );
    }

    /// @dev Remove an account from the internal accounts array and center registry
    /// @param account The account address to remove
    function _removeAccount(address account) internal {
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (_accounts[i] == account) {
                _accounts[i] = _accounts[_accounts.length - 1];
                _accounts.pop();
                break;
            }
        }
        ILOVE20ExtensionCenter(center()).removeAccount(
            tokenAddress,
            actionId,
            account
        );
    }

    /// @dev Prepare action reward for a specific round if not already prepared
    /// @param round The round number to prepare reward for
    function _prepareRewardIfNeeded(uint256 round) internal {
        if (_reward[round] > 0) {
            return;
        }
        uint256 totalActionReward = _mint.mintActionReward(
            tokenAddress,
            round,
            actionId
        );
        _reward[round] = totalActionReward;
    }
}
