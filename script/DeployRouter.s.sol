// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {RouterV1} from "../src/RouterV1.sol";
import {Agent} from "../src/Agent.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Worker} from "../src/Worker.sol";

interface IUpgradeable {
    function upgradeTo(address newImplementation) external;
}

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 1. Deploy the new RouterV1 implementation
        RouterV1 routerV1Impl = new RouterV1();
        console.log("Deployed RouterV1 implementation:", address(routerV1Impl));

        // 2. Upgrade the old router proxy to point to the new RouterV1 implementation
        address RouterProxyAddr = vm.envAddress("PROXY_ADDRESS");
        RouterV1 routerV1Proxy = RouterV1(RouterProxyAddr);

        console.log("Router Version:", routerV1Proxy.VERSION());

        // 3. Attach to existing UUPS proxy (already initialized) and upgrade
        IUpgradeable(RouterProxyAddr).upgradeTo(address(routerV1Impl));
        console.log("Upgraded Router proxy to RouterV1 implementation");

        // 3. Interact with the proxy as RouterV1
        //        RouterV1 routerV1 = RouterV1(RouterProxyAddr);

        // 4. Deploy the new storage proxy, pointing to the old storage contract
        // address storageContract = 0xF18e0C51ca77AcBe089789E6A761cA3700dc92df;
        address storageContract = vm.envAddress("STORAGE_ADDRESS");
        ERC1967Proxy storageProxy =
            new ERC1967Proxy(storageContract, abi.encodeWithSelector(BlueprintV7(storageContract).initialize.selector));
        console.log("Deployed storage proxy:", address(storageProxy));

        // 5. Deploy the Agent contract
        Agent agent = new Agent(address(storageProxy), RouterProxyAddr, routerV1Proxy.VERSION());
        console.log("Deployed Agent:", address(agent));
        console.log("Agent Version:", agent.VERSION());

        // deploy worker contract
        Worker worker = new Worker(address(storageProxy), RouterProxyAddr, routerV1Proxy.VERSION());
        console.log("Deployed Worker:", address(worker));
        console.log("Worker Version:", worker.VERSION());

        // 6. Set forward contracts in router
        routerV1Proxy.setForwardContracts(address(agent), address(storageProxy));
        console.log("Set forward contracts in RouterV1");
        // set worker
        routerV1Proxy.setWorker(address(worker));
        console.log("Set Worker contract in RouterV1");

        // 7. Set Agent contract in BlueprintV7 (via proxy)
        BlueprintV7(address(storageProxy)).setAdminContract(address(agent));
        console.log("Set Agent contract in BlueprintV7");

        BlueprintV7(address(storageProxy)).setAdminContract(address(worker));
        console.log("Set Worker contract in BlueprintV7");

        vm.stopBroadcast();
    }
}
