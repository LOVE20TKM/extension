// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionBase} from "../../src/LOVE20ExtensionBase.sol";
import {IExtensionCore} from "../../src/interface/base/IExtensionCore.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {ExtensionCore} from "../../src/base/ExtensionCore.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";

/**
 * @title MockExtension
 * @dev Mock Extension contract for unit testing
 */
contract MockExtension is LOVE20ExtensionBase {
    bool public shouldFailInitialize;

    constructor(address factory_) LOVE20ExtensionBase(factory_) {}

    function setShouldFailInitialize(bool value) external {
        shouldFailInitialize = value;
    }

    /// @dev Override initialize to add test-specific logic
    function initialize(
        address tokenAddress_,
        uint256 actionId_
    ) public override(IExtensionCore, ExtensionCore) {
        super.initialize(tokenAddress_, actionId_);
        if (shouldFailInitialize) {
            revert("Initialize failed");
        }
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

    function rewardByAccount(
        uint256 /*round*/,
        address /*account*/
    )
        public
        pure
        override(IExtensionReward, ExtensionReward)
        returns (uint256 reward, bool isMinted)
    {
        return (0, false);
    }
}
