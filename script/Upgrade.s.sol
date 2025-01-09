// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BlueprintV3} from "../src/BlueprintV3.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        Options memory opts;
        opts.referenceContract = "BlueprintV1.sol";
        Upgrades.upgradeProxy(proxyAddr, "BlueprintV3.sol", abi.encodeCall(BlueprintV3.initialize, ()), opts);
        BlueprintV3 proxy = BlueprintV3(proxyAddr);
        console.log("New Version:", proxy.VERSION());

        vm.stopBroadcast();
    }
}
