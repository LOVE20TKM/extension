// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "./interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";
import {ILOVE20ExtensionFactory} from "./interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";
import {ILOVE20Launch} from "@core/interfaces/ILOVE20Launch.sol";
import {ILOVE20Stake} from "@core/interfaces/ILOVE20Stake.sol";
import {ILOVE20Submit} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/interfaces/ILOVE20Mint.sol";
import {ILOVE20Random} from "@core/interfaces/ILOVE20Random.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";
import {ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";

uint256 constant DEFAULT_JOIN_AMOUNT = 1000000000000000000; // 1 token

/// @title LOVE20ExtensionBase
/// @notice Abstract base contract for LOVE20 extensions
/// @dev Provides common storage and implementation for all extensions
abstract contract LOVE20ExtensionBase is ILOVE20Extension {
    using ArrayUtils for uint256[];
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

    /// @dev round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    /// @dev account => verificationKey => round => verificationInfo
    mapping(address => mapping(string => mapping(uint256 => string)))
        internal _verificationInfoByRound;

    /// @dev account => verificationKey => round[]
    mapping(address => mapping(string => uint256[]))
        internal _verificationInfoUpdateRounds;

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
    function accounts() external view virtual returns (address[] memory) {
        return _accounts;
    }

    /// @inheritdoc ILOVE20Extension
    function accountsCount() external view virtual returns (uint256) {
        return _accounts.length;
    }

    /// @inheritdoc ILOVE20Extension
    function accountAtIndex(
        uint256 index
    ) external view virtual returns (address) {
        return _accounts[index];
    }

    // ============================================
    // INITIALIZATION
    // ============================================

    /// @inheritdoc ILOVE20Extension
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
        ILOVE20Join join = ILOVE20Join(
            ILOVE20ExtensionCenter(ILOVE20ExtensionFactory(factory).center())
                .joinAddress()
        );
        token.approve(address(join), DEFAULT_JOIN_AMOUNT);

        // Join the action
        join.join(tokenAddress, actionId, DEFAULT_JOIN_AMOUNT, new string[](0));
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Add an account to the internal accounts array and center registry
    /// @param account The account address to add
    function _addAccount(address account) internal virtual {
        _accounts.push(account);
        ILOVE20ExtensionCenter(center()).addAccount(
            tokenAddress,
            actionId,
            account
        );
    }

    /// @dev Remove an account from the internal accounts array and center registry
    /// @param account The account address to remove
    function _removeAccount(address account) internal virtual {
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
    function _prepareRewardIfNeeded(uint256 round) internal virtual {
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

    function _prepareVerifyResultIfNeeded() internal virtual {
        // do nothing
    }

    /// @dev Virtual function to calculate reward for an account in a specific round
    /// @param round The round number
    /// @param account The account address
    /// @return reward The amount of reward for the account
    /// @return isMinted Whether the reward has already been minted
    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 reward, bool isMinted);

    function claimReward(
        uint256 round
    ) public virtual returns (uint256 reward) {
        // Verify phase must be finished for this round
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        // Prepare verify result and reward
        // Note: _prepareVerifyResultIfNeeded() only generates result for current round
        // For completed rounds, verification result should have been generated in that round's verify phase
        _prepareVerifyResultIfNeeded();
        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    /// @dev Internal function to claim reward for a specific round
    /// @param round The round number to claim reward for
    /// @return reward The amount of reward claimed
    function _claimReward(
        uint256 round
    ) internal virtual returns (uint256 reward) {
        // Calculate reward for the user
        bool isMinted;
        (reward, isMinted) = rewardByAccount(round, msg.sender);
        // Check if already minted
        if (isMinted) {
            revert AlreadyClaimed();
        }
        // Update claimed reward
        _claimedReward[round][msg.sender] = reward;

        // Transfer reward to user
        if (reward > 0) {
            ILOVE20Token token = ILOVE20Token(tokenAddress);
            token.transfer(msg.sender, reward);
        }

        emit ClaimReward(tokenAddress, msg.sender, actionId, round, reward);
    }

    // ============================================
    // VERIFICATION INFO
    // ============================================

    /// @inheritdoc ILOVE20Extension
    function updateVerificationInfo(
        string[] memory verificationInfos
    ) public virtual {
        if (verificationInfos.length == 0) {
            return;
        }

        // Get verificationKeys from action info
        ActionInfo memory actionInfo = _submit.actionInfo(
            tokenAddress,
            actionId
        );
        string[] memory verificationKeys = actionInfo.body.verificationKeys;

        if (verificationKeys.length != verificationInfos.length) {
            revert VerificationInfoLengthMismatch();
        }
        for (uint256 i = 0; i < verificationKeys.length; i++) {
            _updateVerificationInfoByKey(
                verificationKeys[i],
                verificationInfos[i]
            );
        }
    }

    /// @dev Internal function to update verification info for a single key
    /// @param verificationKey The verification key
    /// @param aVerificationInfo The verification information
    function _updateVerificationInfoByKey(
        string memory verificationKey,
        string memory aVerificationInfo
    ) internal virtual {
        uint256 currentRound = _join.currentRound();
        uint256[] storage rounds = _verificationInfoUpdateRounds[msg.sender][
            verificationKey
        ];

        if (rounds.length == 0 || rounds[rounds.length - 1] != currentRound) {
            rounds.push(currentRound);
        }

        _verificationInfoByRound[msg.sender][verificationKey][
            currentRound
        ] = aVerificationInfo;

        emit UpdateVerificationInfo({
            tokenAddress: tokenAddress,
            account: msg.sender,
            actionId: actionId,
            verificationKey: verificationKey,
            round: currentRound,
            verificationInfo: aVerificationInfo
        });
    }

    /// @inheritdoc ILOVE20Extension
    function verificationInfo(
        address account,
        string calldata verificationKey
    ) external view virtual returns (string memory) {
        uint256[] memory rounds = _verificationInfoUpdateRounds[account][
            verificationKey
        ];
        if (rounds.length == 0) {
            return "";
        }

        uint256 latestRound = rounds[rounds.length - 1];
        return _verificationInfoByRound[account][verificationKey][latestRound];
    }

    /// @inheritdoc ILOVE20Extension
    function verificationInfoByRound(
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view virtual returns (string memory) {
        uint256[] storage rounds = _verificationInfoUpdateRounds[account][
            verificationKey
        ];

        (bool found, uint256 nearestRound) = rounds.findLeftNearestOrEqualValue(
            round
        );
        if (!found) {
            return "";
        }
        return _verificationInfoByRound[account][verificationKey][nearestRound];
    }

    /// @inheritdoc ILOVE20Extension
    function verificationInfoUpdateRoundsCount(
        address account,
        string calldata verificationKey
    ) external view virtual returns (uint256) {
        return _verificationInfoUpdateRounds[account][verificationKey].length;
    }

    /// @inheritdoc ILOVE20Extension
    function verificationInfoUpdateRoundsAtIndex(
        address account,
        string calldata verificationKey,
        uint256 index
    ) external view virtual returns (uint256) {
        return _verificationInfoUpdateRounds[account][verificationKey][index];
    }
}
