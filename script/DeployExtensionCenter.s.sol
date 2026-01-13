// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "../lib/core/script/BaseScript.sol";
import {ExtensionCenter} from "../src/ExtensionCenter.sol";

/**
 * @title DeployExtensionCenter
 * @notice Script for deploying ExtensionCenter contract
 * @dev Reads deployment parameters from address.params and writes deployed address to address.extension.center.params
 */
contract DeployExtensionCenter is BaseScript {
    address public centerAddress;

    /**
     * @notice Deploy ExtensionCenter with parameters from address.params
     * @dev All required addresses are read from the network's address.params file
     */
    function run() external {
        // Read all required addresses from address.params
        address uniswapV2FactoryAddress = readAddressParamsFile(
            "address.params",
            "uniswapV2FactoryAddress"
        );
        address launchAddress = readAddressParamsFile(
            "address.params",
            "launchAddress"
        );
        address stakeAddress = readAddressParamsFile(
            "address.params",
            "stakeAddress"
        );
        address submitAddress = readAddressParamsFile(
            "address.params",
            "submitAddress"
        );
        address voteAddress = readAddressParamsFile(
            "address.params",
            "voteAddress"
        );
        address joinAddress = readAddressParamsFile(
            "address.params",
            "joinAddress"
        );
        address verifyAddress = readAddressParamsFile(
            "address.params",
            "verifyAddress"
        );
        address mintAddress = readAddressParamsFile(
            "address.params",
            "mintAddress"
        );
        address randomAddress = readAddressParamsFile(
            "address.params",
            "randomAddress"
        );

        // Validate all addresses
        require(
            uniswapV2FactoryAddress != address(0),
            "uniswapV2FactoryAddress not found"
        );
        require(launchAddress != address(0), "launchAddress not found");
        require(stakeAddress != address(0), "stakeAddress not found");
        require(submitAddress != address(0), "submitAddress not found");
        require(voteAddress != address(0), "voteAddress not found");
        require(joinAddress != address(0), "joinAddress not found");
        require(verifyAddress != address(0), "verifyAddress not found");
        require(mintAddress != address(0), "mintAddress not found");
        require(randomAddress != address(0), "randomAddress not found");

        // Deploy ExtensionCenter
        vm.startBroadcast();
        centerAddress = address(
            new ExtensionCenter(
                uniswapV2FactoryAddress,
                launchAddress,
                stakeAddress,
                submitAddress,
                voteAddress,
                joinAddress,
                verifyAddress,
                mintAddress,
                randomAddress
            )
        );
        vm.stopBroadcast();

        // Log deployment info if enabled
        if (!hideLogs) {
            console.log("ExtensionCenter deployed at:", centerAddress);
            console.log("Constructor parameters:");
            console.log("  uniswapV2FactoryAddress:", uniswapV2FactoryAddress);
            console.log("  launchAddress:", launchAddress);
            console.log("  stakeAddress:", stakeAddress);
            console.log("  submitAddress:", submitAddress);
            console.log("  voteAddress:", voteAddress);
            console.log("  joinAddress:", joinAddress);
            console.log("  verifyAddress:", verifyAddress);
            console.log("  mintAddress:", mintAddress);
            console.log("  randomAddress:", randomAddress);
        }

        // Update address file
        updateParamsFile(
            "address.extension.center.params",
            "centerAddress",
            vm.toString(centerAddress)
        );
    }
}
