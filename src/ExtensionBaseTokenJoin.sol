// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionBase} from "./ExtensionBase.sol";
import {
    IExtensionTokenJoin
} from "./interface/IExtensionTokenJoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {RoundHistoryUint256} from "./lib/RoundHistoryUint256.sol";

using SafeERC20 for IERC20;
using RoundHistoryUint256 for RoundHistoryUint256.History;

/// @title ExtensionBaseTokenJoin
/// @notice Abstract base contract for token join extensions
/// @dev Combines TokenJoin with Extension functionality
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete join implementation with:
/// - Join with tokens to participate
/// - Withdraw after block-based waiting period
/// - Integration with extension system
///
/// To implement this contract, you need to:
///
/// Implement joinedValue calculations from ILOVE20Extension
///    - isJoinedValueCalculated() - whether joined value is calculated
///    - joinedValue() - get total joined value
///    - joinedValueByAccount() - get joined value for specific account
///
abstract contract ExtensionBaseTokenJoin is
    ExtensionBase,
    ReentrancyGuard,
    IExtensionTokenJoin
{
    // ============================================
    // STATE VARIABLES - IMMUTABLE CONFIG
    // ============================================

    /// @notice The token that can be joined
    address public immutable joinTokenAddress;

    /// @notice Number of blocks to wait before exit after joining
    uint256 public immutable waitingBlocks;

    // ============================================
    // STATE VARIABLES - JOIN STATE
    // ============================================

    /// @dev Round when account first joined
    mapping(address => uint256) internal _joinedRoundByAccount;

    /// @dev Block when account last joined (for waiting period)
    mapping(address => uint256) internal _joinedBlockByAccount;

    /// @dev Amount history by account
    mapping(address => RoundHistoryUint256.History)
        internal _amountHistoryByAccount;

    /// @dev Total joined amount history
    RoundHistoryUint256.History internal _totalJoinedAmountHistory;

    /// @dev ERC20 interface for the join token
    IERC20 internal _joinToken;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the token join extension
    /// @param factory_ The factory address
    /// @param tokenAddress_ The token address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before exit
    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) ExtensionBase(factory_, tokenAddress_) {
        if (joinTokenAddress_ == address(0)) {
            revert InvalidJoinTokenAddress();
        }
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    // ============================================
    // ILOVE20EXTENSIONTOKENJOIN INTERFACE
    // ============================================

    /// @inheritdoc IExtensionTokenJoin
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual nonReentrant {
        // Auto-initialize if not initialized
        _autoInitialize();

        if (amount == 0) {
            revert JoinAmountZero();
        }

        uint256 currentRound = _join.currentRound();
        bool isFirstJoin = _joinedBlockByAccount[msg.sender] == 0;

        // Update amount history
        uint256 prevAmount = _amountHistoryByAccount[msg.sender].latestValue();
        uint256 newAmount = prevAmount + amount;
        _amountHistoryByAccount[msg.sender].record(currentRound, newAmount);

        // Update total joined amount history
        uint256 prevTotal = _totalJoinedAmountHistory.latestValue();
        _totalJoinedAmountHistory.record(currentRound, prevTotal + amount);

        // Update join block
        _joinedBlockByAccount[msg.sender] = block.number;

        // Add to center accounts only on first join
        if (isFirstJoin) {
            _joinedRoundByAccount[msg.sender] = currentRound;
            _center.addAccount(
                tokenAddress,
                actionId,
                msg.sender,
                verificationInfos
            );
        } else if (verificationInfos.length > 0) {
            _center.updateVerificationInfo(
                tokenAddress,
                actionId,
                msg.sender,
                verificationInfos
            );
        }

        // Transfer tokens from user
        _joinToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Join(
            tokenAddress,
            currentRound,
            actionId,
            msg.sender,
            amount,
            block.number
        );
    }

    /// @inheritdoc IExtensionTokenJoin
    function exit() public virtual nonReentrant {
        uint256 joinedBlock = _joinedBlockByAccount[msg.sender];
        if (joinedBlock == 0) {
            revert NoJoinedAmount();
        }
        if (block.number < joinedBlock + waitingBlocks) {
            revert NotEnoughWaitingBlocks();
        }

        uint256 amount = _amountHistoryByAccount[msg.sender].latestValue();
        uint256 currentRound = _join.currentRound();

        // Clear join state
        _amountHistoryByAccount[msg.sender].record(currentRound, 0);
        _totalJoinedAmountHistory.record(
            currentRound,
            _totalJoinedAmountHistory.latestValue() - amount
        );
        delete _joinedRoundByAccount[msg.sender];
        delete _joinedBlockByAccount[msg.sender];

        // Remove from center accounts
        _center.removeAccount(tokenAddress, actionId, msg.sender);

        // Transfer tokens back to user
        _joinToken.safeTransfer(msg.sender, amount);

        emit Exit(tokenAddress, currentRound, actionId, msg.sender, amount);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @inheritdoc IExtensionTokenJoin
    function joinInfo(
        address account
    )
        external
        view
        virtual
        returns (
            uint256 joinedRound,
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        )
    {
        joinedBlock = _joinedBlockByAccount[account];
        return (
            _joinedRoundByAccount[account],
            _amountHistoryByAccount[account].latestValue(),
            joinedBlock,
            joinedBlock == 0 ? 0 : joinedBlock + waitingBlocks
        );
    }

    /// @inheritdoc IExtensionTokenJoin
    function totalJoinedAmount() public view returns (uint256) {
        return _totalJoinedAmountHistory.latestValue();
    }

    /// @inheritdoc IExtensionTokenJoin
    function totalJoinedAmountByRound(
        uint256 round
    ) public view returns (uint256) {
        return _totalJoinedAmountHistory.value(round);
    }

    /// @inheritdoc IExtensionTokenJoin
    function amountByAccountByRound(
        address account,
        uint256 round
    ) public view returns (uint256) {
        return _amountHistoryByAccount[account].value(round);
    }
}
