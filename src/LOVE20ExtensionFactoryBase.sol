// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionFactory} from "./interface/ILOVE20ExtensionFactory.sol";

/// @title LOVE20ExtensionFactoryBase
/// @notice Abstract base contract for LOVE20 extension factories
/// @dev Provides common storage and implementation for all extension factories
abstract contract LOVE20ExtensionFactoryBase is ILOVE20ExtensionFactory {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @notice The center contract address
    address public immutable center;

    /// @dev extension addresses array
    address[] internal _extensions;

    /// @dev extension address => existence flag
    mapping(address => bool) internal _isExtension;

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @param _center The center contract address
    constructor(address _center) {
        center = _center;
    }

    // ============================================
    // ILOVE20ExtensionFactory INTERFACE
    // ============================================

    /// @inheritdoc ILOVE20ExtensionFactory
    function extensions() external view override returns (address[] memory) {
        return _extensions;
    }

    /// @inheritdoc ILOVE20ExtensionFactory
    function extensionsCount() external view override returns (uint256) {
        return _extensions.length;
    }

    /// @inheritdoc ILOVE20ExtensionFactory
    function extensionsAtIndex(
        uint256 index
    ) external view override returns (address) {
        return _extensions[index];
    }

    /// @inheritdoc ILOVE20ExtensionFactory
    function exists(address extension) external view override returns (bool) {
        return _isExtension[extension];
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Register a new extension
    /// @param extension The extension address to register
    function _registerExtension(address extension) internal {
        _extensions.push(extension);
        _isExtension[extension] = true;
    }
}
