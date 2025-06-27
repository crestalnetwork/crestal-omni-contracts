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
        Options memory opts;
        opts.referenceContract = "BlueprintV6.sol";
        Upgrades.upgradeProxy(
            proxyAddr, "BlueprintV7.sol:BlueprintV7", abi.encodeCall(BlueprintV7.initialize, ()), opts
        );
        BlueprintV7 proxy = BlueprintV7(proxyAddr);
        console.log("New blueprint Version:", proxy.VERSION());

        // 2. deploy router
        RouterV1 routerImpl = new RouterV1();
        console.log("Deployed RouterV1 implementation:", address(routerImpl));

        // 3. Tell the proxy to point to routerV1 implementation
        IERC1967(address(proxy)).upgradeToAndCall(address(routerImpl), "");

        RouterV1 router = RouterV1(payable(address(proxy)));

        // deploy agent contract
        Agent agent = new Agent(router.VERSION());
        console.log("Deployed Agent address:", address(agent));

        // Set Agent contract in router
        router.setAgent(address(agent));

        // deploy newBlueprint contract
        NewBlueprint blueprint = new NewBlueprint(router.VERSION());
        console.log("Deployed NewBlueprint address:", address(blueprint));

        // set newBlueprint contract in router
        router.setBlueprint(address(blueprint));

        address owner = OwnableUpgradeable(address(proxy)).owner();
        console.log("Proxy Owner:", owner,"admin address",address(this));

        // set newBlueprint admin
        router.setBlueprintAdmin(owner);

        // register agent function selectors in router
        bytes4[] memory agentSelectors = new bytes4[](7);
        agentSelectors[0] = bytes4(keccak256("setCopyAgentFee(bytes32,address,uint256)"));
        agentSelectors[1] = bytes4(keccak256("setCopyAgentFeeWithSig(bytes32,address,uint256,bytes)"));
        agentSelectors[2] = bytes4(keccak256("createCopyAgentRequest(bytes32,bytes32,address)"));
        agentSelectors[3] = bytes4(keccak256("createCopyAgentRequestWithSig(bytes32,bytes32,address,bytes)"));
        agentSelectors[4] = bytes4(keccak256("getCreateCopyAgentFee(bytes32,address)"));
        agentSelectors[5] = bytes4(keccak256("userTopUp(address,uint256)"));
        agentSelectors[6] = bytes4(keccak256("userTopUpOther(address,address,uint256)"));

        router.setSelectorTargets(agentSelectors, address(agent));

        vm.stopBroadcast();
    }
}
