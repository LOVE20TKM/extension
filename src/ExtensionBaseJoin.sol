// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionBase} from "./ExtensionBase.sol";
import {IExtensionJoin} from "./interface/IExtensionJoin.sol";

/// @title ExtensionBaseJoin
/// @notice Abstract base contract for token-free join extensions
/// @dev Combines Join with Extension functionality
///
/// ==================== IMPLEMENTATION GUIDE ====================
/// This contract provides a complete join implementation with:
/// - Join without tokens to participate
/// - Withdraw at any time
/// - Integration with extension system
///
/// To implement this contract, you need to:
///
/// Implement joinedValue calculations from ILOVE20Extension
///    - isJoinedValueCalculated() - whether joined value is calculated
///    - joinedValue() - get total joined value
///    - joinedValueByAccount() - get joined value for specific account
///
abstract contract ExtensionBaseJoin is
    ExtensionBase,
    IExtensionJoin
{
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Mapping from account to the round when they joined
    mapping(address => uint256) internal _joinedRound;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the join extension
    /// @param factory_ The factory address
    /// @param tokenAddress_ The token address
    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBase(factory_, tokenAddress_) {}

    // ============================================
    // ILOVE20EXTENSIONJOIN INTERFACE
    // ============================================

    /// @inheritdoc IExtensionJoin
    function joinInfo(
        address account
    ) public view virtual returns (uint256 joinedRound) {
        return _joinedRound[account];
    }

    /// @inheritdoc IExtensionJoin
    function join(string[] memory verificationInfos) public virtual {
        // Auto-initialize if not initialized
        _autoInitialize();

        // Check if already joined
        if (_joinedRound[msg.sender] != 0) {
            revert AlreadyJoined();
        }

        // Record joined round
        _joinedRound[msg.sender] = _join.currentRound();

        // Add to center accounts with verification info
        _center.addAccount(
            tokenAddress,
            actionId,
            msg.sender,
            verificationInfos
        );

        emit Join(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }

    /// @inheritdoc IExtensionJoin
    function exit() public virtual {
        // Check if joined
        if (_joinedRound[msg.sender] == 0) {
            revert NotJoined();
        }

        // Clear joined round
        _joinedRound[msg.sender] = 0;

        // Remove from center accounts
        _center.removeAccount(tokenAddress, actionId, msg.sender);

        emit Exit(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }
}
