// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Extension} from "../../src/interface/ILOVE20Extension.sol";

/**
 * @title MockExtension
 * @dev Mock Extension contract for unit testing
 */
contract MockExtension is ILOVE20Extension {
    address public immutable center;
    address public immutable factory;
    address public tokenAddress;
    uint256 public actionId;
    bool public initializeCalled;
    bool public shouldFailInitialize;

    address[] internal _accounts;
    mapping(address => uint256) internal _joinedValues;
    mapping(uint256 => mapping(address => uint256)) internal _rewards;

    constructor(
        address center_,
        address factory_,
        address tokenAddress_,
        uint256 actionId_
    ) {
        center = center_;
        factory = factory_;
        tokenAddress = tokenAddress_;
        actionId = actionId_;
    }

    function setShouldFailInitialize(bool value) external {
        shouldFailInitialize = value;
    }

    function initialize() external {
        if (shouldFailInitialize) {
            revert("Initialize failed");
        }
        initializeCalled = true;
    }

    function isJoinedValueCalculated() external pure returns (bool) {
        return true;
    }

    function joinedValue() external pure returns (uint256) {
        return 0;
    }

    function joinedValueByAccount(
        address /*account*/
    ) external pure returns (uint256) {
        return 0;
    }

    function accounts() external view returns (address[] memory) {
        return _accounts;
    }

    function accountsCount() external view returns (uint256) {
        return _accounts.length;
    }

    function accountAtIndex(uint256 index) external view returns (address) {
        return _accounts[index];
    }

    function rewardByAccount(
        uint256 round,
        address account
    ) external view returns (uint256 reward, bool isMinted) {
        reward = _rewards[round][account];
        isMinted = reward > 0;
    }

    function claimReward(uint256 /*round*/) external pure returns (uint256) {
        return 0;
    }

    function addAccountForTest(address account) external {
        _accounts.push(account);
    }
}
