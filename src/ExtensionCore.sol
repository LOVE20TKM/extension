// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IExtensionCenter} from "./interface/IExtensionCenter.sol";
import {IExtensionCore} from "./interface/IExtensionCore.sol";
import {
    IExtensionFactory,
    DEFAULT_JOIN_AMOUNT
} from "./interface/IExtensionFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Verify} from "@core/interfaces/ILOVE20Verify.sol";
import {ILOVE20Mint} from "@core/interfaces/ILOVE20Mint.sol";

abstract contract ExtensionCore is IExtensionCore {
    using SafeERC20 for IERC20;

    address public immutable CENTER_ADDRESS;

    address public immutable FACTORY_ADDRESS;

    IExtensionCenter internal immutable _center;

    address public immutable TOKEN_ADDRESS;

    bool public initialized;

    uint256 public actionId;

    ILOVE20Submit internal immutable _submit;
    ILOVE20Vote internal immutable _vote;
    ILOVE20Join internal immutable _join;
    ILOVE20Verify internal immutable _verify;
    ILOVE20Mint internal immutable _mint;

    // round => reward
    mapping(uint256 => uint256) internal _reward;

    constructor(address factory_, address tokenAddress_) {
        if (tokenAddress_ == address(0)) {
            revert InvalidTokenAddress();
        }
        FACTORY_ADDRESS = factory_;
        TOKEN_ADDRESS = tokenAddress_;
        CENTER_ADDRESS = IExtensionFactory(factory_).CENTER_ADDRESS();
        _center = IExtensionCenter(CENTER_ADDRESS);
        _submit = ILOVE20Submit(_center.submitAddress());
        _vote = ILOVE20Vote(_center.voteAddress());
        _join = ILOVE20Join(_center.joinAddress());
        _verify = ILOVE20Verify(_center.verifyAddress());
        _mint = ILOVE20Mint(_center.mintAddress());
    }

    function initializeIfNeeded() external {
        _initializeIfNeeded();
    }

    function _initializeIfNeeded() internal {
        if (initialized) return;

        actionId = _findMatchingActionId();

        initialized = true;

        IERC20(TOKEN_ADDRESS).safeIncreaseAllowance(
            address(_join),
            DEFAULT_JOIN_AMOUNT
        );

        _join.join(
            TOKEN_ADDRESS,
            actionId,
            DEFAULT_JOIN_AMOUNT,
            new string[](0)
        );
        _center.registerActionIfNeeded(TOKEN_ADDRESS, actionId);
    }

    function _findMatchingActionId() internal view returns (uint256) {
        uint256 currentRound = _join.currentRound();
        uint256 count = _vote.votedActionIdsCount(TOKEN_ADDRESS, currentRound);
        uint256 foundActionId = 0;
        bool found = false;

        for (uint256 i = 0; i < count; i++) {
            uint256 aid = _vote.votedActionIdsAtIndex(
                TOKEN_ADDRESS,
                currentRound,
                i
            );
            ActionInfo memory info = _submit.actionInfo(TOKEN_ADDRESS, aid);
            if (info.body.whiteListAddress == address(this)) {
                if (found) revert MultipleActionIdsFound();
                foundActionId = aid;
                found = true;
            }
        }
        if (!found) revert ActionIdNotFound();
        return foundActionId;
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

    function isJoinedValueConverted() external view virtual returns (bool);

    function joinedValue() external view virtual returns (uint256);

    function joinedValueByAccount(
        address account
    ) external view virtual returns (uint256);
}
