// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ExtensionBaseRewardTokenJoin
} from "../ExtensionBaseRewardTokenJoin.sol";
import {ExtensionBase} from "../ExtensionBase.sol";
import {IExtension} from "../interface/IExtension.sol";
import {RoundHistoryUint256} from "../lib/RoundHistoryUint256.sol";

using RoundHistoryUint256 for RoundHistoryUint256.History;

contract ExampleTokenJoin is ExtensionBaseRewardTokenJoin {
    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        ExtensionBaseRewardTokenJoin(
            factory_,
            tokenAddress_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    function isJoinedValueConverted()
        external
        pure
        override(ExtensionBase)
        returns (bool)
    {
        return true;
    }

    function joinedValue()
        external
        view
        override(ExtensionBase)
        returns (uint256)
    {
        return totalJoinedAmount();
    }

    function joinedValueByAccount(
        address account
    ) external view override(ExtensionBase) returns (uint256) {
        return _amountHistoryByAccount[account].latestValue();
    }

    function _calculateReward(
        uint256 round,
        address account
    ) internal view virtual override returns (uint256 reward) {
        (uint256 totalActionReward, ) = _mint.actionRewardByActionIdByAccount(
            TOKEN_ADDRESS,
            round,
            actionId,
            address(this)
        );

        reward =
            (totalActionReward *
                _amountHistoryByAccount[account].latestValue()) /
            totalJoinedAmount();
        return reward;
    }
}
