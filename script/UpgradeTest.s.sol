// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BlueprintUpgradeTest} from "../src/BlueprintUpgradeTest.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        Options memory opts;
        opts.referenceContract = "BlueprintV1.sol";
        Upgrades.upgradeProxy(
            proxyAddr, "BlueprintUpgradeTest.sol", abi.encodeCall(BlueprintUpgradeTest.initialize, ()), opts
        );
        BlueprintUpgradeTest proxy = BlueprintUpgradeTest(proxyAddr);
        console.log("New Version:", proxy.VERSION());

        vm.stopBroadcast();
    }
}
