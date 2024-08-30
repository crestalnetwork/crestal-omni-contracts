// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Blueprint} from "../src/Blueprint.sol";

contract CounterScript is Script {
    Blueprint public blueprint;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        blueprint = new Blueprint();

        vm.stopBroadcast();
    }
}
