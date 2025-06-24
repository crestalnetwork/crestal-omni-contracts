// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {RouterV1} from "../src/RouterV1.sol";
import {Agent} from "../src/Agent.sol";
import {Worker} from "../src/Worker.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

interface IUpgradeable {
    function upgradeTo(address newImplementation) external;
}

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 1.deploy router proxy
        address routerProxy = Upgrades.deployUUPSProxy("RouterV1.sol:RouterV1", abi.encodeCall(RouterV1.initialize, ()));
        console.log("Deployed routerProxy:", routerProxy);
        RouterV1 routerV1 = RouterV1(routerProxy);
        console.log("router Version:", routerV1.VERSION());

        // 2. Deploy/upgrade the new storage proxy, which is previous BlueprintVx contract
        address storageContract = vm.envAddress("STORAGE_ADDRESS");
        Options memory opts;
        opts.referenceContract = "BlueprintV6.sol";
        Upgrades.upgradeProxy(
            storageContract, "BlueprintV7.sol:BlueprintV7", abi.encodeCall(BlueprintV7.initialize, ()), opts
        );
        BlueprintV7 storageProxy = BlueprintV7(storageContract);
        console.log("New storage(blueprint) Version:", storageProxy.VERSION());

        // 3 Deploy the Agent contract
        Agent agent = new Agent(address(storageProxy), routerProxy, routerV1.VERSION());
        console.log("Deployed Agent:", address(agent));
        console.log("Agent Version:", agent.VERSION());

        // 4. deploy worker contract
        Worker worker = new Worker(address(storageProxy), routerProxy, routerV1.VERSION());
        console.log("Deployed Worker:", address(worker));
        console.log("Worker Version:", worker.VERSION());

        // 6. Set forward contracts in router
        routerV1.setForwardContracts(address(agent), address(storageProxy));
        console.log("Set forward contracts in RouterV1");
        // set worker
        routerV1.setWorker(address(worker));
        console.log("Set Worker contract in RouterV1");

        // 7. Set Agent contract in BlueprintV7 (via proxy)
        BlueprintV7(address(storageProxy)).setAdminContract(address(agent));
        console.log("Set Agent contract in BlueprintV7");

        BlueprintV7(address(storageProxy)).setAdminContract(address(worker));
        console.log("Set Worker contract in BlueprintV7");

        vm.stopBroadcast();
    }
}
