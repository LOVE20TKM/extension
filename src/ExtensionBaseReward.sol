// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IReward} from "./interface/IReward.sol";
import {ExtensionBase} from "./ExtensionBase.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";
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

    // round => isRewardPrepared
    mapping(uint256 => bool) internal _rewardPrepared;

    // round => account => claimedReward
    mapping(uint256 => mapping(address => uint256)) internal _claimedRewardByAccount;

    // round => account => isClaimed
    mapping(uint256 => mapping(address => bool)) internal _claimedByAccount;

    // round => burned amount
    mapping(uint256 => uint256) internal _burnedReward;

    // round => burned
    mapping(uint256 => bool) internal _burned;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBase(factory_, tokenAddress_) {}

    function claimReward(
        uint256 round
    ) public virtual nonReentrant returns (uint256 amount) {
        uint256 currentRound = _verify.currentRound();
        if (round >= currentRound) {
            revert RoundNotFinished(currentRound);
        }

        _prepareRewardIfNeeded(round);

        return _claimReward(round);
    }

    function claimRewards(
        uint256[] calldata rounds
    )
        public
        virtual
        nonReentrant
        returns (uint256[] memory claimedRounds, uint256[] memory rewards)
    {
        uint256 len = rounds.length;
        claimedRounds = new uint256[](len);
        rewards = new uint256[](len);
        uint256 count;
        uint256 currentRound = _verify.currentRound();

        for (uint256 i; i < len; ) {
            uint256 round = rounds[i];
            if (round < currentRound && !_claimedByAccount[round][msg.sender]) {
                _prepareRewardIfNeeded(round);
                uint256 amount = _claimReward(round);
                claimedRounds[count] = round;
                rewards[count] = amount;
                unchecked {
                    ++count;
                }
            }
            unchecked {
                ++i;
            }
        }

        assembly {
            mstore(claimedRounds, count)
            mstore(rewards, count)
        }
        return (claimedRounds, rewards);
    }

    function rewardByAccount(
        uint256 round,
        address account
    ) public view virtual returns (uint256 amount, bool claimed) {
        if (_claimedByAccount[round][account]) {
            return (_claimedRewardByAccount[round][account], true);
        }

        return (_calculateReward(round, account), false);
    }

    function reward(uint256 round) public view virtual returns (uint256) {
        if (_rewardPrepared[round]) {
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
        if (_rewardPrepared[round]) {
            return;
        }
        uint256 totalActionReward = _mint.mintActionReward(
            TOKEN_ADDRESS,
            round,
            actionId
        );
        _reward[round] = totalActionReward;
        _rewardPrepared[round] = true;
    }

    function _claimReward(
        uint256 round
    ) internal virtual returns (uint256 amount) {
        bool claimed;
        (amount, claimed) = rewardByAccount(round, msg.sender);
        if (claimed) {
            revert AlreadyClaimed();
        }

        _claimedByAccount[round][msg.sender] = true;
        _claimedRewardByAccount[round][msg.sender] = amount;

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

    function burnRewardIfNeeded(uint256 round) public virtual {
        uint256 currentRound = _verify.currentRound();
        if (round >= currentRound) {
            revert RoundNotFinished(currentRound);
        }
        if (_burned[round]) return;

        _prepareRewardIfNeeded(round);

        uint256 totalReward = _reward[round];
        uint256 burnAmount = _calculateBurnAmount(round, totalReward);
        if (burnAmount == 0) return;

        _burned[round] = true;
        _burnedReward[round] = burnAmount;
        ILOVE20Token(TOKEN_ADDRESS).burn(burnAmount);
        emit BurnReward({
            tokenAddress: TOKEN_ADDRESS,
            round: round,
            actionId: actionId,
            amount: burnAmount
        });
    }

    function burnInfo(
        uint256 round
    ) public view virtual returns (uint256 burnAmount, bool burned) {
        uint256 currentRound = _verify.currentRound();
        if (round >= currentRound) {
            return (0, false);
        }

        burned = _burned[round];
        if (burned) {
            burnAmount = _burnedReward[round];
            return (burnAmount, burned);
        }

        uint256 totalReward = reward(round);
        burnAmount = _calculateBurnAmount(round, totalReward);
    }

    function _calculateBurnAmount(
        uint256 round,
        uint256 totalReward
    ) internal view virtual returns (uint256) {
        if (totalReward == 0) return 0;

        address[] memory accounts = _center.accountsByRound(
            TOKEN_ADDRESS,
            actionId,
            round
        );

        uint256 totalAccountReward;
        for (uint256 i; i < accounts.length; ) {
            (uint256 accountReward, ) = rewardByAccount(round, accounts[i]);
            totalAccountReward += accountReward;
            unchecked {
                ++i;
            }
        }

        if (totalAccountReward == 0) {
            return totalReward;
        }
        return 0;
    }
}
