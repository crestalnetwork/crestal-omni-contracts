// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "lib/forge-std/src/Test.sol";
import "../src/RouterV1.sol";
import "../src/BlueprintV7.sol";
import "../src/Agent.sol";
import {MockERC20} from "./MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RouterV1Test is Test {
    RouterV1 router;
    BlueprintV7 blueprint;
    Agent agent;
    MockERC20 public mockToken;
    address user = address(0xCAFE);

    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        // Deploy RouterV1 as proxy, with address(this) as owner
        RouterV1 impl = new RouterV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
        router = RouterV1(address(proxy));
        router.initialize();

        // Deploy BlueprintV7 and initialize
        blueprint = new BlueprintV7();
        blueprint.initialize();

        // Deploy Agent with blueprint and router as trusted forwarder
        agent = new Agent(address(blueprint), address(router));

        // Set forward contracts in router
        router.setForwardContracts(address(agent), address(blueprint));

        // Set Agent contract in BlueprintV7 (address(this) is owner)
        blueprint.setAgentContract(address(agent));

        // Deploy and mint ERC20 token
        mockToken = new MockERC20();

        // Add payment address to BlueprintV7 (address(this) is owner)
        blueprint.addPaymentAddress(address(mockToken));

        // set crestal wallet address
        blueprint.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
    }

    function testSetCopyAgentFeeViaRouter() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Create agent with token
        bytes32 requestId =
            router.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // Call setCopyAgentFee via router as deployment owner
        router.setCopyAgentFee(requestId, address(mockToken), 123 ether);
        // Check fee is set in blueprint
        assertEq(blueprint.copyAgentFeeMp(requestId, address(mockToken)), 123 ether);
    }

    function testCreateCopyAgentRequestViaRouter() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Create agent with token
        bytes32 requestId =
            router.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        uint256 copyAgentFee = 1000;
        // Set copy agent fee
        router.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // Create copy agent request via router
        // generate copy agent request ID
        bytes32 copyID = keccak256(
            abi.encodePacked(uint256(block.timestamp), address(this), requestId, base64Proposal, block.chainid)
        );

        // transfer some mock tokens to the sender
        mockToken.mint(address(this), copyAgentFee);

        // transfer some mock tokens to relayer
        address relayer = address(0xBEEF);
        mockToken.mint(relayer, copyAgentFee);
        vm.prank(relayer);

        // grant allowance to blueprint address
        mockToken.approve(address(blueprint), copyAgentFee);

        // Expect the CopyAgentRequest event (from Agent, which emits the same event)
        vm.expectEmit(true, false, false, false);
        emit Agent.CopyAgentRequest(copyID, requestId, address(this));

        vm.prank(relayer);

        router.createCopyAgentRequest(copyID, requestId, address(mockToken));
    }

    function testCreateAgentWithTokenViaRouter() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Create agent with token via router
        bytes32 requestId =
            router.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // Check the request ID is not empty
        assertTrue(requestId != bytes32(0));

        // Check the agent request is created in BlueprintV7
        bytes32 latestProjId = blueprint.getLatestUserProjectID(address(this));
        assertEq(projectId, latestProjId);
    }
}
