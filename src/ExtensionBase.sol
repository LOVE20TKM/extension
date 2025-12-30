// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "./interface/IExtensionCenter.sol";
import {IExtension} from "./interface/IExtension.sol";
import {
    IExtensionFactory,
    DEFAULT_JOIN_AMOUNT
} from "./interface/IExtensionFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/interfaces/ILOVE20Mint.sol";

abstract contract ExtensionBase is IExtension, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable factory;

    IExtensionCenter internal immutable _center;

    address public tokenAddress;

    bool public initialized;

    uint256 public actionId;

    ILOVE20Submit internal immutable _submit;
    ILOVE20Vote internal immutable _vote;
    ILOVE20Join internal immutable _join;
    ILOVE20Verify internal immutable _verify;
    ILOVE20Mint internal immutable _mint;

    // round => reward
    mapping(uint256 => uint256) internal _reward;

    // round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedReward;

    constructor(address factory_, address tokenAddress_) {
        if (tokenAddress_ == address(0)) {
            revert InvalidTokenAddress();
        }
        factory = factory_;
        tokenAddress = tokenAddress_;
        _center = IExtensionCenter(IExtensionFactory(factory_).center());
        _submit = ILOVE20Submit(_center.submitAddress());
        _vote = ILOVE20Vote(_center.voteAddress());
        _join = ILOVE20Join(_center.joinAddress());
        _verify = ILOVE20Verify(_center.verifyAddress());
        _mint = ILOVE20Mint(_center.mintAddress());
    }

    function center() public view returns (address) {
        return address(_center);
    }

    function initializeAction() external {
        if (initialized) return;

        _autoInitialize();
    }

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
            tokenAddress,
            round,
            actionId,
            address(this)
        );
        return expectedReward;
    }

    function _doInitialize(uint256 actionId_) internal {
        if (initialized) {
            revert AlreadyInitialized();
        }

        initialized = true;
        actionId = actionId_;

        IERC20(tokenAddress).safeIncreaseAllowance(
            address(_join),
            DEFAULT_JOIN_AMOUNT
        );

        _join.join(
            tokenAddress,
            actionId,
            DEFAULT_JOIN_AMOUNT,
            new string[](0)
        );
    }

    function _findMatchingActionId() internal view returns (uint256) {
        uint256 currentRound = _join.currentRound();
        uint256 count = _vote.votedActionIdsCount(tokenAddress, currentRound);
        uint256 foundActionId = 0;
        bool found = false;

        for (uint256 i = 0; i < count; i++) {
            uint256 aid = _vote.votedActionIdsAtIndex(
                tokenAddress,
                currentRound,
                i
            );
            ActionInfo memory info = _submit.actionInfo(tokenAddress, aid);
            if (info.body.whiteListAddress == address(this)) {
                if (found) revert MultipleActionIdsFound();
                foundActionId = aid;
                found = true;
            }
        }
        if (!found) revert ActionIdNotFound();
        return foundActionId;
    }

    function _autoInitialize() internal {
        if (initialized) {
            return;
        }

        uint256 foundActionId = _findMatchingActionId();
        _doInitialize(foundActionId);
    }

    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual returns (uint256);

    function _prepareRewardIfNeeded(uint256 round) internal virtual {
        if (_reward[round] > 0) {
            return;
        }
        uint256 totalActionReward = _mint.mintActionReward(
            tokenAddress,
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
        _claimedReward[round][msg.sender] = amount;

        if (amount > 0) {
            IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        }

        emit ClaimReward(tokenAddress, round, actionId, msg.sender, amount);
    }
}
