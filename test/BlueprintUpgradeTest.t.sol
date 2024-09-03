// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV1} from "../src/BlueprintV1.sol";
import {BlueprintUpgradeTest} from "../src/BlueprintUpgradeTest.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BlueprintTestUpgrade is Test {
    BlueprintV1 public proxy;

    function setUp() public {
        BlueprintV1 blueprint = new BlueprintV1();

        // Create a proxy pointing to the implementation
        ERC1967Proxy e1967 = new ERC1967Proxy(address(blueprint), abi.encodeWithSignature("initialize()"));

        // Interact with the proxy as if it were the implementation
        proxy = BlueprintV1(address(e1967));
    }

    function test_Upgrade() public {
        string memory ver = proxy.VERSION();
        assertEq(ver, "1.0.0");

        BlueprintUpgradeTest blueup = new BlueprintUpgradeTest();
        proxy.upgradeToAndCall(address(blueup), abi.encodeWithSignature("initialize()"));
        ver = proxy.VERSION();
        assertEq(ver, "TESTING");
    }
}
