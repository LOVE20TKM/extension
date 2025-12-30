// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionBase} from "./ExtensionBase.sol";
import {IExtensionJoin} from "./interface/IExtensionJoin.sol";

abstract contract ExtensionBaseJoin is ExtensionBase, IExtensionJoin {
    // account => joinedRound
    mapping(address => uint256) internal _joinedRound;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBase(factory_, tokenAddress_) {}

    function joinInfo(
        address account
    ) public view virtual returns (uint256 joinedRound) {
        return _joinedRound[account];
    }

    function join(string[] memory verificationInfos) public virtual {
        _autoInitialize();

        if (_joinedRound[msg.sender] != 0) {
            revert AlreadyJoined();
        }

        _joinedRound[msg.sender] = _join.currentRound();

        _center.addAccount(
            tokenAddress,
            actionId,
            msg.sender,
            verificationInfos
        );

        emit Join(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }

    function exit() public virtual {
        if (_joinedRound[msg.sender] == 0) {
            revert NotJoined();
        }

        _joinedRound[msg.sender] = 0;

        _center.removeAccount(tokenAddress, actionId, msg.sender);

        emit Exit(tokenAddress, _join.currentRound(), actionId, msg.sender);
    }
}
