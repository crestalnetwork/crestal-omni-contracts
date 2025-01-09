// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV1} from "../src/BlueprintV1.sol";
import {BlueprintUpgradeTest} from "../src/BlueprintUpgradeTest.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BlueprintV2} from "../src/BlueprintV2.sol";
import {BlueprintV3} from "../src/BlueprintV3.sol";

contract BlueprintTestUpgrade is Test {
    BlueprintV1 public proxy;
    address public solverAddress;

    function setUp() public {
        BlueprintV1 blueprint = new BlueprintV1();

        // Create a proxy pointing to the implementation
        ERC1967Proxy e1967 = new ERC1967Proxy(address(blueprint), abi.encodeWithSignature("initialize()"));

        // Interact with the proxy as if it were the implementation
        proxy = BlueprintV1(address(e1967));

        // init solver address
        solverAddress = address(0x275960ad41DbE218bBf72cDF612F88b5C6f40648);
    }

    function test_Upgrade() public {
        string memory ver = proxy.VERSION();
        assertEq(ver, "1.0.0");

        BlueprintUpgradeTest blueup = new BlueprintUpgradeTest();
        proxy.upgradeToAndCall(address(blueup), abi.encodeWithSignature("initialize()"));
        ver = proxy.VERSION();
        assertEq(ver, "TESTING");
    }

    function test_UpgradeV2() public {
        string memory ver = proxy.VERSION();
        assertEq(ver, "1.0.0");

        bytes32 pid = proxy.createProjectID();
        bytes32 projId = proxy.getLatestUserProjectID(address(this));
        assertEq(pid, projId);

        bytes32 deploymentRequestId =
            proxy.createDeploymentRequest(projId, solverAddress, "test base64 param", "test server url");
        bytes32 latestDeploymentRequestId = proxy.getLatestDeploymentRequestID(address(this));
        assertEq(deploymentRequestId, latestDeploymentRequestId);

        BlueprintV2 blueprintV2 = new BlueprintV2();
        proxy.upgradeToAndCall(address(blueprintV2), abi.encodeWithSignature("initialize()"));
        ver = proxy.VERSION();
        assertEq(ver, "2.0.0");

        // create proposal request with old project id from v1
        bytes32 proposalId = proxy.createProposalRequest(projId, "test base64 param", "test server url");
        bytes32 latestProposalId = proxy.getLatestProposalRequestID(address(this));
        assertEq(proposalId, latestProposalId);

        // get old project id
        projId = proxy.getLatestUserProjectID(address(this));
        assertEq(pid, projId);

        // get old deployment request id
        latestDeploymentRequestId = proxy.getLatestDeploymentRequestID(address(this));
        assertEq(deploymentRequestId, latestDeploymentRequestId);
    }

    function test_UpgradeV3() public {
        string memory ver = proxy.VERSION();
        assertEq(ver, "1.0.0");

        bytes32 pid = proxy.createProjectID();
        bytes32 projId = proxy.getLatestUserProjectID(address(this));
        assertEq(pid, projId);

        bytes32 deploymentRequestId =
                            proxy.createDeploymentRequest(projId, solverAddress, "test base64 param", "test server url");
        bytes32 latestDeploymentRequestId = proxy.getLatestDeploymentRequestID(address(this));
        assertEq(deploymentRequestId, latestDeploymentRequestId);

        BlueprintV3 blueprintV3 = new BlueprintV3();
        proxy.upgradeToAndCall(address(blueprintV3), abi.encodeWithSignature("initialize()"));
        ver = proxy.VERSION();
        assertEq(ver, "3.0.0");

        // create proposal request with old project id from v1
        bytes32 proposalId = proxy.createProposalRequest(projId, "test base64 param", "test server url");
        bytes32 latestProposalId = proxy.getLatestProposalRequestID(address(this));
        assertEq(proposalId, latestProposalId);

        // get old project id
        projId = proxy.getLatestUserProjectID(address(this));
        assertEq(pid, projId);

        // get old deployment request id
        latestDeploymentRequestId = proxy.getLatestDeploymentRequestID(address(this));
        assertEq(deploymentRequestId, latestDeploymentRequestId);

    }
}
