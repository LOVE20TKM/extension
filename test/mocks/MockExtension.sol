// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IReward} from "../../src/interface/IReward.sol";
import {ExtensionBase} from "../../src/ExtensionBase.sol";
import {ExtensionCore} from "../../src/ExtensionCore.sol";
import {IExtensionCore} from "../../src/interface/IExtensionCore.sol";

/**
 * @title MockExtension
 * @dev Mock Extension contract for unit testing
 */
contract MockExtension is ExtensionBase {
    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBase(factory_, tokenAddress_) {}

    /// @dev Test helper to simulate initialization without going through _doInitialize
    function mockInitialize(uint256 actionId_) external {
        initialized = true;
        actionId = actionId_;
    }

    function isJoinedValueConverted()
        external
        pure
        override(ExtensionCore)
        returns (bool)
    {
        return true;
    }

    function joinedValue()
        external
        pure
        override(ExtensionCore)
        returns (uint256)
    {
        return 0;
    }

    function joinedValueByAccount(
        address /*account*/
    ) external pure override(ExtensionCore) returns (uint256) {
        return 0;
    }

    function rewardByAccount(
        uint256 /*round*/,
        address /*account*/
    )
        public
        pure
        override(ExtensionBase)
        returns (uint256 reward, bool isMinted)
    {
        return (0, false);
    }

    function _calculateReward(
        uint256 /*round*/,
        address /*account*/
    ) internal pure override returns (uint256) {
        return 0;
    }

    function exit() external pure {
        revert("Exit not implemented in mock");
    }
}
