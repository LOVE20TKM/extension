// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    ExtensionFactoryBase
} from "../../src/ExtensionFactoryBase.sol";
import {MockExtension} from "./MockExtension.sol";

/**
 * @title MockExtensionFactory
 * @dev Mock Extension Factory for unit testing
 */
contract MockExtensionFactory is ExtensionFactoryBase {
    constructor(address center_) ExtensionFactoryBase(center_) {}

    function createExtension(
        address tokenAddress_
    ) external returns (address extension) {
        extension = address(new MockExtension(address(this), tokenAddress_));
        _registerExtension(extension, tokenAddress_);
    }

    // Helper function for tests to register external extensions
    function registerExtension(
        address extension,
        address tokenAddress_
    ) external {
        _registerExtension(extension, tokenAddress_);
    }
}
