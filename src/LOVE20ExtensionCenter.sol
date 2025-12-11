// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "./interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LOVE20ExtensionCenter is ILOVE20ExtensionCenter {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ------ state variables ------
    address public immutable uniswapV2FactoryAddress;
    address public immutable launchAddress;
    address public immutable stakeAddress;
    address public immutable submitAddress;
    address public immutable voteAddress;
    address public immutable joinAddress;
    address public immutable verifyAddress;
    address public immutable mintAddress;
    address public immutable randomAddress;

    // tokenAddress => actionId => account => bool
    mapping(address => mapping(uint256 => mapping(address => bool)))
        internal _isAccountJoined;

    // tokenAddress => account => actionIds array
    mapping(address => mapping(address => uint256[]))
        internal _actionIdsByAccount;

    // tokenAddress => actionId => accounts set
    mapping(address => mapping(uint256 => EnumerableSet.AddressSet))
        internal _accounts;

    // ------ modifiers ------
    modifier onlyExtension(address tokenAddress, uint256 actionId) {
        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        if (actionInfo.body.whiteListAddress != msg.sender) {
            revert OnlyExtensionCanCall();
        }
        _;
    }

    // ------ constructor ------
    constructor(
        address uniswapV2FactoryAddress_,
        address launchAddress_,
        address stakeAddress_,
        address submitAddress_,
        address voteAddress_,
        address joinAddress_,
        address verifyAddress_,
        address mintAddress_,
        address randomAddress_
    ) {
        if (uniswapV2FactoryAddress_ == address(0))
            revert InvalidUniswapV2FactoryAddress();
        if (launchAddress_ == address(0)) revert InvalidLaunchAddress();
        if (stakeAddress_ == address(0)) revert InvalidStakeAddress();
        if (submitAddress_ == address(0)) revert InvalidSubmitAddress();
        if (voteAddress_ == address(0)) revert InvalidVoteAddress();
        if (joinAddress_ == address(0)) revert InvalidJoinAddress();
        if (verifyAddress_ == address(0)) revert InvalidVerifyAddress();
        if (mintAddress_ == address(0)) revert InvalidMintAddress();
        if (randomAddress_ == address(0)) revert InvalidRandomAddress();

        uniswapV2FactoryAddress = uniswapV2FactoryAddress_;
        launchAddress = launchAddress_;
        stakeAddress = stakeAddress_;
        submitAddress = submitAddress_;
        voteAddress = voteAddress_;
        joinAddress = joinAddress_;
        verifyAddress = verifyAddress_;
        mintAddress = mintAddress_;
        randomAddress = randomAddress_;
    }

    // ------ extension query ------
    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        return actionInfo.body.whiteListAddress;
    }

    // ------ account management (only extension can call) ------
    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external onlyExtension(tokenAddress, actionId) {
        if (_isAccountJoined[tokenAddress][actionId][account]) {
            revert AccountAlreadyJoined();
        }

        // set account joined
        _isAccountJoined[tokenAddress][actionId][account] = true;

        // add actionId to account's list
        _actionIdsByAccount[tokenAddress][account].push(actionId);

        // add account to action's list
        _accounts[tokenAddress][actionId].add(account);

        emit AccountAdded(tokenAddress, actionId, account);
    }

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external onlyExtension(tokenAddress, actionId) {
        if (!_isAccountJoined[tokenAddress][actionId][account]) {
            revert AccountNotJoined();
        }

        // set account joined to false
        _isAccountJoined[tokenAddress][actionId][account] = false;

        // remove actionId from account's list
        ArrayUtils.remove(_actionIdsByAccount[tokenAddress][account], actionId);

        // remove account from action's list
        _accounts[tokenAddress][actionId].remove(account);

        emit AccountRemoved(tokenAddress, actionId, account);
    }

    // ------ account status queries ------
    function isAccountJoined(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool) {
        return _isAccountJoined[tokenAddress][actionId][account];
    }

    function actionIdsByAccount(
        address tokenAddress,
        address account
    ) external view returns (uint256[] memory) {
        return _actionIdsByAccount[tokenAddress][account];
    }

    function actionIdsByAccountCount(
        address tokenAddress,
        address account
    ) external view returns (uint256) {
        return _actionIdsByAccount[tokenAddress][account].length;
    }

    function actionIdsByAccountAtIndex(
        address tokenAddress,
        address account,
        uint256 index
    ) external view returns (uint256) {
        return _actionIdsByAccount[tokenAddress][account][index];
    }

    // ------ accounts by action queries ------
    function accounts(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address[] memory) {
        return _accounts[tokenAddress][actionId].values();
    }

    function accountsCount(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256) {
        return _accounts[tokenAddress][actionId].length();
    }

    function accountsAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) external view returns (address) {
        return _accounts[tokenAddress][actionId].at(index);
    }
}
