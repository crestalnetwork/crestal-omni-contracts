// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Blueprint} from "../src/Blueprint.sol";

contract BlueprintTest is Test {
    Blueprint public blueprint;

    function setUp() public {
        blueprint = new Blueprint();
    }

    // TODO: This is just an example of how to write Solidity-native tests
    // Fill in more tests later!
    function test_ProjectID() public {
        bytes32 pid = blueprint.createProjectID();
        bytes32 projId = blueprint.latestProjectID(msg.sender);
        assertEq(pid, projId);
    }
}
