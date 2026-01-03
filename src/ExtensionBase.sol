// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtension} from "./interface/IExtension.sol";
import {ExtensionCore} from "./ExtensionCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract ExtensionBase is ExtensionCore, IExtension, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionCore(factory_, tokenAddress_) {}

    function claimReward(
        uint256 round
    ) public virtual nonReentrant returns (uint256 amount) {
        if (round >= _verify.currentRound()) {
            revert RoundNotFinished();
        }

        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 amount, bool isMinted) {
        uint256 claimedReward = _claimedReward[round][account];
        if (claimedReward > 0) {
            return (claimedReward, true);
        }

        return (_calculateReward(round, account), false);
    }

    function reward(uint256 round) public view virtual returns (uint256) {
        if (_reward[round] > 0) {
            return _reward[round];
        }
        (uint256 expectedReward, ) = _mint.actionRewardByActionIdByAccount(
            TOKEN_ADDRESS,
            round,
            actionId,
            address(this)
        );
        return expectedReward;
    }

    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual returns (uint256);

    function _claimReward(
        uint256 round
    ) internal virtual returns (uint256 amount) {
        bool isMinted;
        (amount, isMinted) = rewardByAccount(round, msg.sender);
        if (isMinted) {
            revert AlreadyClaimed();
        }
        _claimedReward[round][msg.sender] = amount;

        if (amount > 0) {
            IERC20(TOKEN_ADDRESS).safeTransfer(msg.sender, amount);
        }

        emit ClaimReward(TOKEN_ADDRESS, round, actionId, msg.sender, amount);
    }
}
