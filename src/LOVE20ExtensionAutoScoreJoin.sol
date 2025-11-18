// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionAutoScore} from "./LOVE20ExtensionAutoScore.sol";
import {
    ILOVE20ExtensionAutoScoreJoin
} from "./interface/ILOVE20ExtensionAutoScoreJoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title LOVE20ExtensionAutoScoreJoin
/// @notice Abstract base contract for auto-score-based join LOVE20 extensions
/// @dev Provides common join functionality with block-based waiting period mechanism for AutoScore extensions
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete join implementation with:
/// - Join with tokens to participate
/// - Withdraw after block-based waiting period
/// - Minimum governance votes requirement
///
/// To implement this contract, you need to:
///
/// Implement calculateScores() and calculateScore() from LOVE20ExtensionAutoScore
///    - Define how scores are calculated based on joined amounts
///    - See LOVE20ExtensionAutoScore for details
///
abstract contract LOVE20ExtensionAutoScoreJoin is
    LOVE20ExtensionAutoScore,
    ILOVE20ExtensionAutoScoreJoin
{
    // ============================================
    // STATE VARIABLES - IMMUTABLE CONFIG
    // ============================================

    /// @notice The token that can be joined
    address public immutable joinTokenAddress;

    /// @notice Number of blocks to wait before withdrawal after joining
    uint256 public immutable waitingBlocks;

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

    /// @notice Initialize the join extension
    /// @param factory_ The factory address
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) LOVE20ExtensionAutoScore(factory_) {
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    // ============================================
    // USER OPERATIONS
    // ============================================

    /// @inheritdoc ILOVE20ExtensionAutoScoreJoin
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual {
        _prepareVerifyResultIfNeeded();

        JoinInfo storage info = _joinInfo[msg.sender];
        if (info.joinedBlock != 0) {
            revert AlreadyJoined();
        }
        if (amount == 0) {
            revert JoinAmountZero();
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

    /// @inheritdoc ILOVE20ExtensionAutoScoreJoin
    function withdraw() public virtual {
        _prepareVerifyResultIfNeeded();

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
    // VIEW FUNCTIONS - JOIN INFO
    // ============================================

    /// @inheritdoc ILOVE20ExtensionAutoScoreJoin
    function joinInfo(
        address account
    )
        external
        view
        virtual
        returns (uint256 amount, uint256 joinedBlock, uint256 withdrawableBlock)
    {
        return (
            _joinInfo[account].amount,
            _joinInfo[account].joinedBlock,
            _getWithdrawableBlock(account)
        );
    }

    /// @inheritdoc ILOVE20ExtensionAutoScoreJoin
    function canWithdraw(address account) external view virtual returns (bool) {
        return _canWithdraw(account);
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Check if an account can withdraw
    /// @param account The account to check
    /// @return Whether the account can withdraw
    function _canWithdraw(
        address account
    ) internal view virtual returns (bool) {
        JoinInfo storage info = _joinInfo[account];
        if (info.joinedBlock == 0) {
            return false;
        }
        return block.number >= _getWithdrawableBlock(account);
    }

    /// @dev Get the block number when an account can withdraw
    /// @param account The account to check
    /// @return The withdrawable block number (0 if not joined)
    function _getWithdrawableBlock(
        address account
    ) internal view virtual returns (uint256) {
        uint256 joinedBlock = _joinInfo[account].joinedBlock;
        if (joinedBlock == 0) {
            return 0;
        }
        return joinedBlock + waitingBlocks;
    }
}
