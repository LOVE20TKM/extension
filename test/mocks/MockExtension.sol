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

    constructor(address center_, address factory_) {
        center = center_;
        factory = factory_;
    }

    function setShouldFailInitialize(bool value) external {
        shouldFailInitialize = value;
    }

    function initialize(address tokenAddress_, uint256 actionId_) external {
        if (shouldFailInitialize) {
            revert("Initialize failed");
        }
        tokenAddress = tokenAddress_;
        actionId = actionId_;
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

    function accounts() external pure returns (address[] memory) {
        return new address[](0);
    }

    function accountsCount() external pure returns (uint256) {
        return 0;
    }

    function accountAtIndex(uint256 /*index*/) external pure returns (address) {
        return address(0);
    }

    function rewardByAccount(
        uint256 /*round*/,
        address /*account*/
    ) external pure returns (uint256 reward, bool isMinted) {
        return (0, false);
    }

    function claimReward(uint256 /*round*/) external pure returns (uint256) {
        return 0;
    }
}
