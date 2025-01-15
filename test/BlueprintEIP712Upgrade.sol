// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintEIP712Upgrade} from "../src/BlueprintEIP712Upgrade.sol";
import {stdError} from "forge-std/StdError.sol";
import {BlueprintV1} from "../src/BlueprintV1.sol";
import {BlueprintUpgradeTest} from "../src/BlueprintUpgradeTest.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BlueprintV2} from "../src/BlueprintV2.sol";
import {BlueprintV3} from "../src/BlueprintV3.sol";

contract EIP712Test is Test {
    BlueprintV1 public proxy;
    BlueprintV3 public proxyV3;
    bytes32 public projectId;
    address public solverAddress;

    function setUp() public {
        BlueprintV1 blueprint = new BlueprintV1();

        // Create a proxy pointing to the implementation
        ERC1967Proxy e1967 = new ERC1967Proxy(address(blueprint), abi.encodeWithSignature("initialize()"));

        // Interact with the proxy as if it were the implementation
        proxy = BlueprintV1(address(e1967));

        BlueprintV2 blueprintV2 = new BlueprintV2();
        proxy.upgradeToAndCall(address(blueprintV2), abi.encodeWithSignature("initialize()"));
        string memory ver = proxy.VERSION();
        assertEq(ver, "2.0.0");

        BlueprintV3 blueprintV3 = new BlueprintV3();
        proxy.upgradeToAndCall(address(blueprintV3), abi.encodeWithSignature("initialize()"));
        ver = proxy.VERSION();
        assertEq(ver, "3.0.0");

        // Interact with the proxy as if it were the implementation
        proxyV3 = BlueprintV3(address(proxy));

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);

        // init solver address
        solverAddress = address(0x275960ad41DbE218bBf72cDF612F88b5C6f40648);
    }

    function test_getRequestProposalDigest() public {
        string memory base64RecParam = "data:image/png;base64,sdfasdfsdf";
        string memory serverURL = "https://example.com";

        // Generate the hash of the request proposal from old eip712
        bytes32 digest1 = proxyV3.getRequestProposalDigest(projectId, base64RecParam, serverURL);

        BlueprintEIP712Upgrade blueprintEIP712Upgrade = new BlueprintEIP712Upgrade();
        proxy.upgradeToAndCall(address(blueprintEIP712Upgrade), abi.encodeWithSignature("initialize()"));
        string memory ver = proxy.VERSION();
        assertEq(ver, "3.0.0");
        proxyV3 = BlueprintV3(address(proxy));
        // Generate the hash of the request proposal from new eip712
        bytes32 digest2 = proxyV3.getRequestProposalDigest(projectId, base64RecParam, serverURL);
        assertEq(digest1, digest2);
    }

    function test_UpgradeEIP712() public {
        bytes32 pid = proxyV3.createProjectID();
        bytes32 projId = proxyV3.getLatestUserProjectID(address(this));
        assertEq(pid, projId);

        bytes32 deploymentRequestId =
            proxyV3.createDeploymentRequest(projId, solverAddress, "test base64 param", "test server url");
        bytes32 latestDeploymentRequestId = proxyV3.getLatestDeploymentRequestID(address(this));
        assertEq(deploymentRequestId, latestDeploymentRequestId);

        BlueprintEIP712Upgrade blueprintEIP712Upgrade = new BlueprintEIP712Upgrade();
        proxy.upgradeToAndCall(address(blueprintEIP712Upgrade), abi.encodeWithSignature("initialize()"));
        string memory ver = proxy.VERSION();
        assertEq(ver, "3.0.0");
        proxyV3 = BlueprintV3(address(proxy));

        // create proposal request with old project id from v3
        bytes32 proposalId = proxyV3.createProposalRequest(projId, "test base64 param", "test server url");
        bytes32 latestProposalId = proxyV3.getLatestProposalRequestID(address(this));
        assertEq(proposalId, latestProposalId);

        // get old project id
        projId = proxyV3.getLatestUserProjectID(address(this));
        assertEq(pid, projId);

        // get old deployment request id
        latestDeploymentRequestId = proxyV3.getLatestDeploymentRequestID(address(this));
        assertEq(deploymentRequestId, latestDeploymentRequestId);
    }
}
