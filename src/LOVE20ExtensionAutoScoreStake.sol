// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionAutoScore} from "./LOVE20ExtensionAutoScore.sol";
import {
    ILOVE20ExtensionAutoScoreStake
} from "./interface/ILOVE20ExtensionAutoScoreStake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";

/// @title LOVE20ExtensionAutoScoreStake
/// @notice Abstract base contract for auto-score-based stake LOVE20 extensions
/// @dev Provides common staking functionality with waiting period mechanism for AutoScore extensions
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete staking implementation with:
/// - Stake tokens to participate
/// - Unstake request with waiting period
/// - Withdraw after waiting period
/// - Minimum governance votes requirement
///
/// To implement this contract, you need to:
///
/// Implement calculateScores() and calculateScore() from LOVE20ExtensionAutoScore
///    - Define how scores are calculated based on staked amounts
///    - See LOVE20ExtensionAutoScore for details
///
/// ==============================================================
///
abstract contract LOVE20ExtensionAutoScoreStake is
    LOVE20ExtensionAutoScore,
    ILOVE20ExtensionAutoScoreStake
{
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

    /// @notice Initialize the stake extension
    /// @param factory_ The factory address
    /// @param stakeTokenAddress_ The token that can be staked
    /// @param waitingPhases_ Number of phases to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required to stake
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    ) LOVE20ExtensionAutoScore(factory_) {
        stakeTokenAddress = stakeTokenAddress_;
        waitingPhases = waitingPhases_;
        minGovVotes = minGovVotes_;
        _stakeToken = IERC20(stakeTokenAddress_);
    }

    // ============================================
    // USER OPERATIONS
    // ============================================

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function stake(uint256 amount, string[] memory verificationInfos) external {
        _prepareVerifyResultIfNeeded();

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

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function unstake() external {
        _prepareVerifyResultIfNeeded();

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

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function withdraw() external {
        _prepareVerifyResultIfNeeded();

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
    // VIEW FUNCTIONS - STAKE INFO
    // ============================================

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function stakeInfo(
        address account
    ) external view returns (uint256 amount, uint256 requestedUnstakeRound) {
        return (
            _stakeInfo[account].amount,
            _stakeInfo[account].requestedUnstakeRound
        );
    }

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function unstakers() external view returns (address[] memory) {
        return _unstakers;
    }

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function unstakersCount() external view returns (uint256) {
        return _unstakers.length;
    }

    /// @inheritdoc ILOVE20ExtensionAutoScoreStake
    function unstakersAtIndex(uint256 index) external view returns (address) {
        return _unstakers[index];
    }
}
