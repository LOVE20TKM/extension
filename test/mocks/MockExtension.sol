// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionBase} from "../../src/LOVE20ExtensionBase.sol";

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

    /// @dev Override _afterInitialize to add test-specific logic
    function _afterInitialize() internal view override {
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
        override(LOVE20ExtensionBase)
        returns (uint256 reward, bool isMinted)
    {
        return (0, false);
    }

    function _prepareVerifyResultIfNeeded(
        uint256 /*round*/
    ) internal pure override {}
}
