// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IJoin} from "./interface/IJoin.sol";
import {ExtensionBaseReward} from "./ExtensionBaseReward.sol";

abstract contract ExtensionBaseRewardJoin is ExtensionBaseReward, IJoin {
    // ReentrancyGuard is inherited from ExtensionBaseReward
    // account => joinedRound
    mapping(address => uint256) internal _joinedRoundByAccount;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseReward(factory_, tokenAddress_) {}

    function joinInfo(
        address account
    ) public view virtual returns (uint256 joinedRound) {
        return _joinedRoundByAccount[account];
    }

    function join(
        string[] memory verificationInfos
    ) public virtual nonReentrant {
        initializeIfNeeded();

        if (_joinedRoundByAccount[msg.sender] != 0) {
            revert AlreadyJoined();
        }

        _joinedRoundByAccount[msg.sender] = _join.currentRound();

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

    function exit() public virtual nonReentrant {
        if (_joinedRoundByAccount[msg.sender] == 0) {
            revert NotJoined();
        }

        _joinedRoundByAccount[msg.sender] = 0;

        _center.removeAccount(TOKEN_ADDRESS, actionId, msg.sender);

        emit Exit({
            tokenAddress: TOKEN_ADDRESS,
            round: _join.currentRound(),
            actionId: actionId,
            account: msg.sender
        });
    }
}
