// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LOVE20} from "../src/LOVE20.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        LOVE20 token = new LOVE20("LOVE Token", "LOVE", 18, 1000000 * 10 ** 18);

        vm.stopBroadcast();

        // Log the deployed address
        console.log("LOVE20 deployed at:", address(token));
    }
}
