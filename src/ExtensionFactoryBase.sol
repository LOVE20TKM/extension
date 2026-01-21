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

abstract contract ExtensionFactoryBase is IExtensionFactory {
    using SafeERC20 for IERC20;

    address public immutable CENTER_ADDRESS;

    address[] internal _extensions;

    // extension => isExtension
    mapping(address => bool) internal _isExtension;

    // extension => creator
    mapping(address => address) internal _extensionCreator;

    constructor(address _center) {
        CENTER_ADDRESS = _center;
    }

    function extensions() external view override returns (address[] memory) {
        return _extensions;
    }

    function extensionsCount() external view override returns (uint256) {
        return _extensions.length;
    }

    function extensionsAtIndex(
        uint256 index
    ) external view override returns (address) {
        return _extensions[index];
    }

    function exists(address extension) external view override returns (bool) {
        return _isExtension[extension];
    }

    function _registerExtension(
        address extension,
        address tokenAddress
    ) internal {
        _extensions.push(extension);
        _isExtension[extension] = true;
        _extensionCreator[extension] = msg.sender;
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            extension,
            DEFAULT_JOIN_AMOUNT
        );
        emit CreateExtension({
            extension: extension,
            tokenAddress: tokenAddress
        });
    }

    function extensionCreator(
        address extension
    ) external view override returns (address) {
        return _extensionCreator[extension];
    }
}
