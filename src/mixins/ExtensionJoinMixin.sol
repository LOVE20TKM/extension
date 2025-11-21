// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionCoreMixin} from "./ExtensionCoreMixin.sol";
import {ExtensionAccountMixin} from "./ExtensionAccountMixin.sol";
import {ExtensionVerificationMixin} from "./ExtensionVerificationMixin.sol";
import {ITokenJoin} from "../interface/base/ITokenJoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ExtensionJoinMixin
/// @notice Mixin providing join/exit functionality with token-based participation
/// @dev Implements ITokenJoin interface with block-based waiting period mechanism
abstract contract ExtensionJoinMixin is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionVerificationMixin
{
    // Import errors, events, and struct from ITokenJoin
    error AlreadyJoined();
    error JoinAmountZero();
    error NoJoinedAmount();
    error NotEnoughWaitingBlocks();

    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount,
        uint256 joinedBlock
    );
    event Exit(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );

    // Use JoinInfo struct from ITokenJoin
    struct JoinInfo {
        uint256 amount;
        uint256 joinedBlock;
    }

    address public immutable joinTokenAddress;

    uint256 public immutable waitingBlocks;

    uint256 public totalJoinedAmount;

    // account => JoinInfo
    mapping(address => JoinInfo) internal _joinInfo;

    IERC20 internal _joinToken;

    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) ExtensionCoreMixin(factory_) {
        joinTokenAddress = joinTokenAddress_;
        waitingBlocks = waitingBlocks_;
        _joinToken = IERC20(joinTokenAddress_);
    }

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

    // ============================================
    // VIEW FUNCTIONS
    // ============================================

    function joinInfo(
        address account
    )
        external
        view
        returns (uint256 amount, uint256 joinedBlock, uint256 exitableBlock)
    {
        return (
            _joinInfo[account].amount,
            _joinInfo[account].joinedBlock,
            _getExitableBlock(account)
        );
    }

    function canExit(address account) external view returns (bool) {
        return _canExit(account);
    }

    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================

    function _canExit(address account) internal view returns (bool) {
        JoinInfo storage info = _joinInfo[account];
        if (info.joinedBlock == 0) {
            return false;
        }
        return block.number >= _getExitableBlock(account);
    }

    function _getExitableBlock(
        address account
    ) internal view returns (uint256) {
        uint256 joinedBlock = _joinInfo[account].joinedBlock;
        if (joinedBlock == 0) {
            return 0;
        }
        return joinedBlock + waitingBlocks;
    }
}
