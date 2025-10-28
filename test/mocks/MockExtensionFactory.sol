// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionFactoryBase} from "../../src/LOVE20ExtensionFactoryBase.sol";

/**
 * @title MockExtensionFactory
 * @dev Mock Extension Factory for unit testing
 */
contract MockExtensionFactory is LOVE20ExtensionFactoryBase {
    constructor(address center_) LOVE20ExtensionFactoryBase(center_) {}

    /// @dev Test helper function to manually register extensions
    function addExtension(address tokenAddress, address extension) external {
        _registerExtension(tokenAddress, extension);
    }
}
