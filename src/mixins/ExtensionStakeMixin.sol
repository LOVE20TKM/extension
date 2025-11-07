// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "./ExtensionAccountMixin.sol";
import {ExtensionVerificationMixin} from "./ExtensionVerificationMixin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title ExtensionStakeMixin
/// @notice Mixin for staking functionality with phase-based waiting period
/// @dev Provides stake/unstake/withdraw operations with configurable parameters
abstract contract ExtensionStakeMixin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionVerificationMixin
{
    // ============================================
    // ERRORS
    // ============================================
    error UnstakeRequested();
    error StakeAmountZero();
    error InsufficientGovVotes();
    error NoStakedAmount();
    error UnstakeNotRequested();
    error NotEnoughWaitingPhases();

    // ============================================
    // EVENTS
    // ============================================
    event Stake(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );
    event Unstake(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );
    event Withdraw(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );

    // ============================================
    // STRUCTS
    // ============================================
    struct StakeInfo {
        uint256 amount;
        uint256 requestedUnstakeRound;
    }

    // ============================================
    // STATE VARIABLES - IMMUTABLE CONFIG
    // ============================================

    /// @notice The token that can be staked
    address public immutable stakeTokenAddress;

    /// @notice Number of phases to wait before withdrawal after unstaking
    uint256 public immutable waitingPhases;

    /// @notice Minimum governance votes required to stake
    uint256 public immutable minGovVotes;

    // ============================================
    // STATE VARIABLES - STAKE STATE
    // ============================================

    /// @notice Total amount currently staked
    uint256 public totalStakedAmount;

    /// @notice Total amount that has been unstaked but not withdrawn
    uint256 public totalUnstakedAmount;

    /// @dev List of accounts that have requested unstaking
    address[] internal _unstakers;

    /// @dev Mapping from account to their stake information
    mapping(address => StakeInfo) internal _stakeInfo;

    /// @dev ERC20 interface for the stake token
    IERC20 internal _stakeToken;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory contract address
    /// @param stakeTokenAddress_ The token that can be staked
    /// @param waitingPhases_ Number of phases to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required to stake
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    ) ExtensionCoreMixin(factory_) {
        stakeTokenAddress = stakeTokenAddress_;
        waitingPhases = waitingPhases_;
        minGovVotes = minGovVotes_;
        _stakeToken = IERC20(stakeTokenAddress_);
    }

    // ============================================
    // PUBLIC FUNCTIONS
    // ============================================

    /// @notice Stake tokens
    /// @param amount Amount of tokens to stake
    /// @param verificationInfos Verification information
    function stake(
        uint256 amount,
        string[] memory verificationInfos
    ) external virtual {
        _doStake(amount, verificationInfos);
    }

    /// @dev Internal stake logic that can be called by child contracts
    function _doStake(
        uint256 amount,
        string[] memory verificationInfos
    ) internal {
        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        if (amount == 0) {
            revert StakeAmountZero();
        }

        bool isNewStaker = info.amount == 0;
        if (isNewStaker) {
            uint256 userGovVotes = _stake.validGovVotes(
                tokenAddress,
                msg.sender
            );
            if (userGovVotes < minGovVotes) {
                revert InsufficientGovVotes();
            }

            _addAccount(msg.sender);
        }

        info.amount += amount;
        totalStakedAmount += amount;
        _stakeToken.transferFrom(msg.sender, address(this), amount);

        // Update verification info if provided
        updateVerificationInfo(verificationInfos);

        emit Stake(tokenAddress, msg.sender, actionId, amount);
    }

    /// @notice Request to unstake tokens
    function unstake() external virtual {
        _doUnstake();
    }

    /// @dev Internal unstake logic that can be called by child contracts
    function _doUnstake() internal {
        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.amount == 0) {
            revert NoStakedAmount();
        }
        if (info.requestedUnstakeRound != 0) {
            revert UnstakeRequested();
        }
        uint256 amount = info.amount;
        info.requestedUnstakeRound = _join.currentRound();
        totalStakedAmount -= amount;
        totalUnstakedAmount += amount;

        _removeAccount(msg.sender);
        _unstakers.push(msg.sender);

        emit Unstake(tokenAddress, msg.sender, actionId, amount);
    }

    /// @notice Withdraw unstaked tokens after waiting period
    function withdraw() external virtual {
        _doWithdraw();
    }

    /// @dev Internal withdraw logic that can be called by child contracts
    function _doWithdraw() internal {
        StakeInfo storage info = _stakeInfo[msg.sender];
        if (info.requestedUnstakeRound == 0) {
            revert UnstakeNotRequested();
        }
        if (
            _join.currentRound() - info.requestedUnstakeRound <= waitingPhases
        ) {
            revert NotEnoughWaitingPhases();
        }
        uint256 amount = info.amount;
        info.amount = 0;
        info.requestedUnstakeRound = 0;
        totalUnstakedAmount -= amount;

        ArrayUtils.remove(_unstakers, msg.sender);

        _stakeToken.transfer(msg.sender, amount);
        emit Withdraw(tokenAddress, msg.sender, actionId, amount);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get stake info for an account
    function stakeInfo(
        address account
    ) external view returns (uint256 amount, uint256 requestedUnstakeRound) {
        return (
            _stakeInfo[account].amount,
            _stakeInfo[account].requestedUnstakeRound
        );
    }

    /// @notice Get all unstakers
    function unstakers() external view returns (address[] memory) {
        return _unstakers;
    }

    /// @notice Get count of unstakers
    function unstakersCount() external view returns (uint256) {
        return _unstakers.length;
    }

    /// @notice Get unstaker at specific index
    function unstakersAtIndex(uint256 index) external view returns (address) {
        return _unstakers[index];
    }
}
