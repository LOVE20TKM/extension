// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionFactoryBase} from "../../src/LOVE20ExtensionFactoryBase.sol";
import {MockExtension} from "./MockExtension.sol";

/**
 * @title MockExtensionFactory
 * @dev Mock Extension Factory for unit testing
 */
contract MockExtensionFactory is LOVE20ExtensionFactoryBase {
    constructor(address center_) LOVE20ExtensionFactoryBase(center_) {}

    function createExtension() external returns (address extension) {
        extension = address(new MockExtension(address(this)));
        _registerExtension(extension);
    }

    // Helper function for tests to register external extensions
    function registerExtension(address extension) external {
        _registerExtension(extension);
    }
}
