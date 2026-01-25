// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ExtensionBaseRewardTokenJoin
} from "../ExtensionBaseRewardTokenJoin.sol";
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

        uint256 totalJoinedAmount = _joinedAmountHistory.value(round);
        if (totalJoinedAmount == 0) {
            return 0;
        }
        reward =
            (totalActionReward *
                _joinedAmountByAccountHistory[account].value(round)) /
            totalJoinedAmount;
        return reward;
    }
}
