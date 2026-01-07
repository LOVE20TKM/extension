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

    function joinedAmount()
        external
        view
        override(ExtensionBaseRewardTokenJoin)
        returns (uint256)
    {
        return _totalJoinedAmountHistory.latestValue();
    }

    function joinedAmountByAccount(
        address account
    ) external view override(ExtensionBaseRewardTokenJoin) returns (uint256) {
        return _amountHistoryByAccount[account].latestValue();
    }

    function joinedAmountTokenAddress()
        external
        view
        override(ExtensionBaseRewardTokenJoin)
        returns (address)
    {
        return JOIN_TOKEN_ADDRESS;
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
            _totalJoinedAmountHistory.latestValue();
        return reward;
    }
}
