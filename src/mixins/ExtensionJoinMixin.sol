// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "./ExtensionAccountMixin.sol";
import {ExtensionVerificationMixin} from "./ExtensionVerificationMixin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ExtensionJoinMixin
/// @notice Mixin for join functionality with block-based waiting period
/// @dev Provides join/withdraw operations with configurable parameters
abstract contract ExtensionJoinMixin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionVerificationMixin
{
    // ============================================
    // ERRORS
    // ============================================
    error AlreadyJoined();
    error JoinAmountZero();
    error InsufficientGovVotes();
    error NoJoinedAmount();
    error NotEnoughWaitingBlocks();

    // ============================================
    // EVENTS
    // ============================================
    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount,
        uint256 joinedBlock
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
    struct JoinInfo {
        uint256 amount;
        uint256 joinedBlock;
    }

    // ============================================
    // STATE VARIABLES - IMMUTABLE CONFIG
    // ============================================

    /// @notice The token that can be joined
    address public immutable joinTokenAddress;

    /// @notice Number of blocks to wait before withdrawal after joining
    uint256 public immutable waitingBlocks;

    /// @notice Minimum governance votes required to join
    uint256 public immutable minGovVotes;

    // ============================================
    // STATE VARIABLES - JOIN STATE
    // ============================================

    /// @notice Total amount currently joined
    uint256 public totalJoinedAmount;

    /// @dev Mapping from account to their join information
    mapping(address => JoinInfo) internal _joinInfo;

    /// @dev ERC20 interface for the join token
    IERC20 internal _joinToken;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required to join
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_,
        uint256 minGovVotes_
    ) ExtensionCoreMixin(factory_) {
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        minGovVotes = minGovVotes_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    // ============================================
    // PUBLIC FUNCTIONS
    // ============================================

    /// @notice Join with tokens
    /// @param amount Amount of tokens to join
    /// @param verificationInfos Verification information
    function join(uint256 amount, string[] memory verificationInfos) external virtual {
        JoinInfo storage info = _joinInfo[msg.sender];
        if (info.joinedBlock != 0) {
            revert AlreadyJoined();
        }
        if (amount == 0) {
            revert JoinAmountZero();
        }

        // Check minimum governance votes requirement
        uint256 userGovVotes = _stake.validGovVotes(tokenAddress, msg.sender);
        if (userGovVotes < minGovVotes) {
            revert InsufficientGovVotes();
        }

        // Update state
        info.amount = amount;
        info.joinedBlock = block.number;
        totalJoinedAmount += amount;

        // Add to accounts list
        _addAccount(msg.sender);

        // Transfer tokens from user
        _joinToken.transferFrom(msg.sender, address(this), amount);

        // Update verification info if provided
        updateVerificationInfo(verificationInfos);

        emit Join(tokenAddress, msg.sender, actionId, amount, block.number);
    }

    /// @notice Withdraw joined tokens
    function withdraw() external virtual {
        JoinInfo storage info = _joinInfo[msg.sender];
        if (!_canWithdraw(msg.sender)) {
            if (info.joinedBlock == 0) {
                revert NoJoinedAmount();
            }
            revert NotEnoughWaitingBlocks();
        }

        uint256 amount = info.amount;

        // Clear join info
        info.amount = 0;
        info.joinedBlock = 0;
        totalJoinedAmount -= amount;

        // Remove from accounts list
        _removeAccount(msg.sender);

        // Transfer tokens back to user
        _joinToken.transfer(msg.sender, amount);

        emit Withdraw(tokenAddress, msg.sender, actionId, amount);
    }

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    /// @notice Get join info for an account
    function joinInfo(
        address account
    ) external view returns (uint256 amount, uint256 joinedBlock) {
        return (_joinInfo[account].amount, _joinInfo[account].joinedBlock);
    }

    /// @notice Check if an account can withdraw
    function canWithdraw(address account) external view returns (bool) {
        return _canWithdraw(account);
    }

    /// @notice Get the block number when an account can withdraw
    function withdrawableBlock(address account) external view returns (uint256) {
        return _getWithdrawableBlock(account);
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================

    /// @dev Check if an account can withdraw
    function _canWithdraw(address account) internal view returns (bool) {
        JoinInfo storage info = _joinInfo[account];
        if (info.joinedBlock == 0) {
            return false;
        }
        return block.number >= _getWithdrawableBlock(account);
    }

    /// @dev Get the block number when an account can withdraw
    function _getWithdrawableBlock(address account) internal view returns (uint256) {
        uint256 joinedBlock = _joinInfo[account].joinedBlock;
        if (joinedBlock == 0) {
            return 0;
        }
        return joinedBlock + waitingBlocks;
    }
}

