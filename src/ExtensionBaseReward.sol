// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IReward} from "./interface/IReward.sol";
import {ExtensionBase} from "./ExtensionBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract ExtensionBaseReward is
    ExtensionBase,
    IReward,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // round => reward
    mapping(uint256 => uint256) internal _reward;

    // round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    // round => account => isClaimed
    mapping(uint256 => mapping(address => bool)) internal _claimed;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBase(factory_, tokenAddress_) {}

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
        if (_claimed[round][account]) {
            return (_claimedReward[round][account], true);
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

    function _prepareRewardIfNeeded(uint256 round) internal virtual {
        if (_reward[round] > 0) {
            return;
        }
        uint256 totalActionReward = _mint.mintActionReward(
            TOKEN_ADDRESS,
            round,
            actionId
        );
        _reward[round] = totalActionReward;
    }

    function _claimReward(
        uint256 round
    ) internal virtual returns (uint256 amount) {
        bool isMinted;
        (amount, isMinted) = rewardByAccount(round, msg.sender);
        if (isMinted) {
            revert AlreadyClaimed();
        }

        _claimed[round][msg.sender] = true;
        _claimedReward[round][msg.sender] = amount;

        if (amount == 0) {
            return 0;
        }

        IERC20(TOKEN_ADDRESS).safeTransfer({to: msg.sender, value: amount});
        emit ClaimReward({
            tokenAddress: TOKEN_ADDRESS,
            round: round,
            actionId: actionId,
            account: msg.sender,
            amount: amount
        });
        return amount;
    }

    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual returns (uint256);
}
