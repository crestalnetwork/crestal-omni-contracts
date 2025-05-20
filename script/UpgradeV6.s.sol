// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BlueprintV6} from "../src/BlueprintV6.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        Options memory opts;
        opts.referenceContract = "BlueprintV5.sol";
        Upgrades.upgradeProxy(
            proxyAddr, "BlueprintV6.sol:BlueprintV6", abi.encodeCall(BlueprintV6.initialize, ()), opts
        );
        BlueprintV6 proxy = BlueprintV6(proxyAddr);
        console.log("New Version:", proxy.VERSION());

        vm.stopBroadcast();
    }
}
