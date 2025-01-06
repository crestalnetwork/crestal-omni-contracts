// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV3} from "../src/BlueprintV3.sol";
import {Blueprint} from "../src/Blueprint.sol";
import {stdError} from "forge-std/StdError.sol";

contract BlueprintTest is Test {
    BlueprintV3 public blueprint;
    bytes32 public projectId;
    address public solverAddress;
    address public workerAddress;
    address public dummyAddress;

    function setUp() public {
        blueprint = new BlueprintV3();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
    }

    function test_VERSION() public view {
        string memory ver = blueprint.VERSION();
        assertEq(ver, "3.0.0");
    }

    function test_setWorkerPublicKey() public {
        bytes memory publicKey = hex"123456";
        blueprint.setWorkerPublicKey(publicKey);

        bytes memory storedPublicKey = blueprint.getWorkerPublicKey(address(this));
        assertEq(storedPublicKey, publicKey);
    }

    function test_getWorkerAddresses() public {
        // Case 1: One worker
        bytes memory publicKey1 = hex"123456";
        blueprint.setWorkerPublicKey(publicKey1);

        address[] memory workerAddresses = blueprint.getWorkerAddresses();
        assertEq(workerAddresses.length, 1);
        assertEq(workerAddresses[0], address(this));

        // Case 2: Two workers
        bytes memory publicKey2 = hex"abcdef";
        vm.prank(dummyAddress);
        blueprint.setWorkerPublicKey(publicKey2);

        workerAddresses = blueprint.getWorkerAddresses();
        assertEq(workerAddresses.length, 2);
        assertEq(workerAddresses[0], address(this));
        assertEq(workerAddresses[1], dummyAddress);
    }

    function test_createProjectIdAndPrivateDeploymentWithConfig() public {
        // Define the configuration parameters
        string memory base64Proposal = "test base64 proposal";
        address privateWorkerAddress = workerAddress;
        string memory serverURL = "http://example.com";

        // Expect the UpdateDeploymentConfig event to be emitted
        vm.expectEmit(true, true, true, true);
        emit Blueprint.UpdateDeploymentConfig(
            projectId,
            keccak256(
                abi.encodePacked(
                    uint256(block.timestamp), address(this), base64Proposal, uint256(block.chainid), uint256(0)
                )
            ),
            privateWorkerAddress,
            "Encrypted config for deployment"
        );

        // Call the function with the configuration parameters
        bytes32 requestID = blueprint.createProjectIdAndPrivateDeploymentWithConfig(
            projectId, base64Proposal, privateWorkerAddress, serverURL
        );

        // Verify that the returned request ID is not zero
        assert(requestID != bytes32(0));

        // Verify that the deployment status is updated correctly
        (Blueprint.Status status, address workerAddr) = blueprint.getDeploymentStatus(requestID);
        assertTrue(status == Blueprint.Status.Pickup);
        assertEq(workerAddr, privateWorkerAddress);
    }
}
