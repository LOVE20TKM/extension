// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCore} from "./ExtensionCore.sol";
import {ExtensionAccounts} from "./ExtensionAccounts.sol";
import {ExtensionVerificationInfo} from "./ExtensionVerificationInfo.sol";
import {ITokenJoin} from "../interface/base/ITokenJoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TokenJoin
/// @notice Base contract providing token-based join/exit functionality
/// @dev Implements ITokenJoin interface with ERC20 token participation and block-based waiting period
abstract contract TokenJoin is
    ExtensionCore,
    ExtensionAccounts,
    ExtensionVerificationInfo,
    ITokenJoin
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

    /// @notice Total amount currently joined
    uint256 public totalJoinedAmount;

    /// @dev Mapping from account to their join information
    mapping(address => JoinInfo) internal _joinInfo;

    /// @dev ERC20 interface for the join token
    IERC20 internal _joinToken;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the token join extension
    /// @param joinTokenAddress_ The token that can be joined
    /// @param waitingBlocks_ Number of blocks to wait before exit
    /// @dev Note: ExtensionCore initialization happens through another inheritance path
    constructor(address joinTokenAddress_, uint256 waitingBlocks_) {
        // ExtensionCore will be initialized through another inheritance path
        // We only handle join-specific initialization here
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

    // ============================================
    // ITOKENJOIN INTERFACE
    // ============================================

    /// @inheritdoc ITokenJoin
    function join(
        uint256 amount,
        string[] memory verificationInfos
    ) public virtual {
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

    /// @inheritdoc ITokenJoin
    function exit() public virtual {
        JoinInfo storage info = _joinInfo[msg.sender];
        if (!_canExit(msg.sender)) {
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

        emit Exit(tokenAddress, msg.sender, actionId, amount);
    }

    /// @inheritdoc ITokenJoin
    function joinInfo(
        address account
    )
        external
        view
        virtual
        returns (uint256 amount, uint256 joinedBlock, uint256 exitableBlock)
    {
        return (
            _joinInfo[account].amount,
            _joinInfo[account].joinedBlock,
            _getExitableBlock(account)
        );
    }

    /// @inheritdoc ITokenJoin
    function canExit(address account) external view virtual returns (bool) {
        return _canExit(account);
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Check if an account can exit
    /// @param account The account to check
    /// @return Whether the account can exit
    function _canExit(address account) internal view virtual returns (bool) {
        JoinInfo storage info = _joinInfo[account];
        if (info.joinedBlock == 0) {
            return false;
        }
        return block.number >= _getExitableBlock(account);
    }

    /// @dev Get the block number when an account can exit
    /// @param account The account to check
    /// @return The exitable block number (0 if not joined)
    function _getExitableBlock(
        address account
    ) internal view virtual returns (uint256) {
        uint256 joinedBlock = _joinInfo[account].joinedBlock;
        if (joinedBlock == 0) {
            return 0;
        }
        return joinedBlock + waitingBlocks;
    }
}
