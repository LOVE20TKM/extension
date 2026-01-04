// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExtensionBaseReward} from "./ExtensionBaseReward.sol";
import {IJoin} from "./interface/IJoin.sol";

abstract contract ExtensionBaseRewardJoin is ExtensionBaseReward, IJoin {
    // account => joinedRound
    mapping(address => uint256) internal _joinedRound;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseReward(factory_, tokenAddress_) {}

    function joinInfo(
        address account
    ) public view virtual returns (uint256 joinedRound) {
        return _joinedRound[account];
    }

    function join(string[] memory verificationInfos) public virtual {
        initializeIfNeeded();

        if (_joinedRound[msg.sender] != 0) {
            revert AlreadyJoined();
        }

        _joinedRound[msg.sender] = _join.currentRound();

        _center.addAccount(
            TOKEN_ADDRESS,
            actionId,
            msg.sender,
            verificationInfos
        );

        emit Join({
            tokenAddress: TOKEN_ADDRESS,
            round: _join.currentRound(),
            actionId: actionId,
            account: msg.sender
        });
    }

    function exit() public virtual {
        if (_joinedRound[msg.sender] == 0) {
            revert NotJoined();
        }

        _joinedRound[msg.sender] = 0;

        _center.removeAccount(TOKEN_ADDRESS, actionId, msg.sender);

        emit Exit({
            tokenAddress: TOKEN_ADDRESS,
            round: _join.currentRound(),
            actionId: actionId,
            account: msg.sender
        });
    }
}
