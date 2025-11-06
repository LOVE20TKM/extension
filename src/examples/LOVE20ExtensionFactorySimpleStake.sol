// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LOVE20ExtensionSimpleStake} from "./LOVE20ExtensionSimpleStake.sol";
import {LOVE20ExtensionFactoryBase} from "../LOVE20ExtensionFactoryBase.sol";

/// @title LOVE20ExtensionFactorySimpleStake
/// @notice Factory contract for creating LOVE20ExtensionSimpleStake instances
contract LOVE20ExtensionFactorySimpleStake is LOVE20ExtensionFactoryBase {
    // ============================================
    // STATE VARIABLES
    // ============================================

    /// @dev Mapping from extension address to its parameters
    mapping(address => ExtensionParams) private _extensionParams;

    // ============================================
    // STRUCTS
    // ============================================

    /// @notice Parameters for SimpleStake extension
    struct ExtensionParams {
        address stakeTokenAddress;
        uint256 waitingPhases;
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

    /// @notice Create a new SimpleStake extension
    /// @param stakeTokenAddress_ The token to stake
    /// @param waitingPhases_ Number of phases to wait before withdrawal
    /// @param minGovVotes_ Minimum governance votes required
    /// @return The address of the created extension
    function createExtension(
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    ) external returns (address) {
        LOVE20ExtensionSimpleStake extension = new LOVE20ExtensionSimpleStake(
            address(this),
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        );

        _extensionParams[address(extension)] = ExtensionParams({
            stakeTokenAddress: stakeTokenAddress_,
            waitingPhases: waitingPhases_,
            minGovVotes: minGovVotes_
        });

        _registerExtension(address(extension));

        return address(extension);
    }

    /// @notice Get the parameters of an extension
    /// @param extension_ The extension address
    /// @return stakeTokenAddress The stake token address
    /// @return waitingPhases The waiting phases
    /// @return minGovVotes The minimum governance votes
    function extensionParams(
        address extension_
    )
        external
        view
        returns (
            address stakeTokenAddress,
            uint256 waitingPhases,
            uint256 minGovVotes
        )
    {
        ExtensionParams memory params = _extensionParams[extension_];
        return (
            params.stakeTokenAddress,
            params.waitingPhases,
            params.minGovVotes
        );
    }
}
