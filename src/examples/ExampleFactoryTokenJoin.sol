// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExampleTokenJoin} from "./ExampleTokenJoin.sol";
import {LOVE20ExtensionFactoryBase} from "../LOVE20ExtensionFactoryBase.sol";

/// @title ExampleFactoryTokenJoin
/// @notice Factory contract for creating ExampleTokenJoin instances
contract ExampleFactoryTokenJoin is LOVE20ExtensionFactoryBase {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Mapping from extension address to its parameters
    mapping(address => ExtensionParams) private _extensionParams;

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Parameters for ExampleTokenJoin extension
    struct ExtensionParams {
        address joinTokenAddress;
        uint256 waitingBlocks;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================

    /// @notice Initialize the factory
    /// @param center_ The center contract address
    constructor(address center_) LOVE20ExtensionFactoryBase(center_) {}

    // ============================================
    // FACTORY FUNCTIONS
    // ============================================

    /// @notice Create a new ExampleTokenJoin extension
    /// @param joinTokenAddress_ The token to join with
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    /// @return The address of the created extension
    function createExtension(
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) external returns (address) {
        ExampleTokenJoin extension = new ExampleTokenJoin(
            address(this),
            joinTokenAddress_,
            waitingBlocks_
        );

        _extensionParams[address(extension)] = ExtensionParams({
            joinTokenAddress: joinTokenAddress_,
            waitingBlocks: waitingBlocks_
        });

        _registerExtension(address(extension));

        return address(extension);
    }

    /// @notice Get the parameters of an extension
    /// @param extension_ The extension address
    /// @return joinTokenAddress The join token address
    /// @return waitingBlocks The waiting blocks
    function extensionParams(
        address extension_
    ) external view returns (address joinTokenAddress, uint256 waitingBlocks) {
        ExtensionParams memory params = _extensionParams[extension_];
        return (params.joinTokenAddress, params.waitingBlocks);
    }
}
