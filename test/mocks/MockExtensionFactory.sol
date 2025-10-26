// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionFactory} from "../../src/interface/ILOVE20ExtensionFactory.sol";

/**
 * @title MockExtensionFactory
 * @dev Mock Extension Factory for unit testing
 */
contract MockExtensionFactory is ILOVE20ExtensionFactory {
    address public immutable center;
    mapping(address => bool) internal _exists;
    mapping(address => address[]) internal _extensions;

    constructor(address center_) {
        center = center_;
    }

    function addExtension(address tokenAddress, address extension) external {
        _exists[extension] = true;
        _extensions[tokenAddress].push(extension);
    }

    function extensions(
        address tokenAddress
    ) external view returns (address[] memory) {
        return _extensions[tokenAddress];
    }

    function extensionsCount(
        address tokenAddress
    ) external view returns (uint256) {
        return _extensions[tokenAddress].length;
    }

    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address) {
        return _extensions[tokenAddress][index];
    }

    function exists(address extension) external view returns (bool) {
        return _exists[extension];
    }
}
