// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BlueprintV1} from "../src/BlueprintV1.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        Options memory opts;
        opts.referenceContract = "BlueprintV1.sol";
        Upgrades.upgradeProxy(proxyAddr, "BlueprintV1.sol", abi.encodeCall(BlueprintV1.initialize, ()), opts);
        BlueprintV1 proxy = BlueprintV1(proxyAddr);
        console.log("New Version:", proxy.VERSION());

        vm.stopBroadcast();
    }
}
