// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionSimpleJoin} from "./LOVE20ExtensionSimpleJoin.sol";
import {LOVE20ExtensionFactoryBase} from "../LOVE20ExtensionFactoryBase.sol";

/// @title LOVE20ExtensionFactorySimpleJoin
/// @notice Factory contract for creating LOVE20ExtensionSimpleJoin instances
contract LOVE20ExtensionFactorySimpleJoin is LOVE20ExtensionFactoryBase {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Mapping from extension address to its parameters
    mapping(address => ExtensionParams) private _extensionParams;

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Parameters for SimpleJoin extension
    struct ExtensionParams {
        address joinTokenAddress;
        uint256 waitingBlocks;
        uint256 minGovVotes;
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

    /// @notice Create a new SimpleJoin extension
    /// @param joinTokenAddress_ The token to join with
    /// @param waitingBlocks_ Number of blocks to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required
    /// @return The address of the created extension
    function createExtension(
        address joinTokenAddress_,
        uint256 waitingBlocks_,
        uint256 minGovVotes_
    ) external returns (address) {
        LOVE20ExtensionSimpleJoin extension = new LOVE20ExtensionSimpleJoin(
            address(this),
            joinTokenAddress_,
            waitingBlocks_,
            minGovVotes_
        );

        _extensionParams[address(extension)] = ExtensionParams({
            joinTokenAddress: joinTokenAddress_,
            waitingBlocks: waitingBlocks_,
            minGovVotes: minGovVotes_
        });

        _registerExtension(address(extension));

        return address(extension);
    }

    /// @notice Get the parameters of an extension
    /// @param extension_ The extension address
    /// @return joinTokenAddress The join token address
    /// @return waitingBlocks The waiting blocks
    /// @return minGovVotes The minimum governance votes
    function extensionParams(
        address extension_
    )
        external
        view
        returns (
            address joinTokenAddress,
            uint256 waitingBlocks,
            uint256 minGovVotes
        )
    {
        ExtensionParams memory params = _extensionParams[extension_];
        return (
            params.joinTokenAddress,
            params.waitingBlocks,
            params.minGovVotes
        );
    }
}
