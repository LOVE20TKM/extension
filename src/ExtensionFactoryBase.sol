// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    IExtensionFactory,
    DEFAULT_JOIN_AMOUNT
} from "./interface/IExtensionFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ExtensionFactoryBase
/// @notice Abstract base contract for extension factories
/// @dev Provides common storage and implementation for all extension factories
abstract contract ExtensionFactoryBase is IExtensionFactory {
    using SafeERC20 for IERC20;
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
    // IExtensionFactory INTERFACE
    // ============================================

    /// @inheritdoc IExtensionFactory
    function extensions() external view override returns (address[] memory) {
        return _extensions;
    }

    /// @inheritdoc IExtensionFactory
    function extensionsCount() external view override returns (uint256) {
        return _extensions.length;
    }

    /// @inheritdoc IExtensionFactory
    function extensionsAtIndex(
        uint256 index
    ) external view override returns (address) {
        return _extensions[index];
    }

    /// @inheritdoc IExtensionFactory
    function exists(address extension) external view override returns (bool) {
        return _isExtension[extension];
    }

    // ============================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================

    /// @dev Register extension and transfer initial tokens for auto-initialization
    /// @param extension The extension address to register
    /// @param tokenAddress The token address to transfer
    function _registerExtension(
        address extension,
        address tokenAddress
    ) internal {
        _extensions.push(extension);
        _isExtension[extension] = true;
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            extension,
            DEFAULT_JOIN_AMOUNT
        );
    }
}
