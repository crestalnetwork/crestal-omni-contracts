// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {RouterV1} from "../src/RouterV1.sol";
import {Agent} from "../src/Agent.sol";
import {NewBlueprint} from "../src/NewBlueprint.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

interface IERC1967 {
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 1. upgrade to V7 to solve compatibility issues with RouterV1
        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        //todo: if no any storage layout changes, we can skip upgrade
        RouterV1 router = RouterV1(payable(address(proxyAddr)));
        console.log("New RouterV1 Version:", router.VERSION());

        // deploy agent contract if agent contract got changes
        Agent agent = new Agent(router.VERSION());
        console.log("Deployed Agent address:", address(agent));

        // Set Agent contract in router
        router.setAgent(address(agent));

        // deploy newBlueprint contract if newBlueprint contract got changes
        NewBlueprint blueprint = new NewBlueprint(router.VERSION());
        console.log("Deployed NewBlueprint address:", address(blueprint));

        // set newBlueprint contract in router
        router.setBlueprint(address(blueprint));

        address owner = OwnableUpgradeable(address(router)).owner();
        console.log("Proxy Owner:", owner);
        // set newBlueprint admin
        router.setBlueprintAdmin(owner);

        // register selectors in router
        // todo: register selectors in router if any new functions added in agent or blueprint

        vm.stopBroadcast();
    }
}
