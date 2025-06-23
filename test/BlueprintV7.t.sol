pragma solidity ^0.8.26;

import "../src/Agent.sol";
import {BlueprintCore} from "../src/BlueprintCore.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {Blueprint} from "../src/Blueprint.sol";
import {MockERC20} from "./MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/StdError.sol";

contract BlueprintTest is Test {
    BlueprintV7 public blueprint;
    Agent public agent;
    MockERC20 public mockToken;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        blueprint = new BlueprintV7();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        mockToken = new MockERC20();

        // Deploy Agent with blueprint and router as trusted forwarder random forward address
        agent = new Agent(address(blueprint), address(blueprint), "1.0.0");

        // Set Agent contract in BlueprintV7 (address(this) is owner)
        blueprint.setAdminContract(address(agent));

        // set crestal wallet address
        blueprint.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
    }

    function test_setGlobalPlatformFee() public {
        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));
        // Set the global platform fee to 5%
        uint256 baseFee = 100000; // 100000 nation token
        blueprint.setGlobalPlatformFee(baseFee, address(mockToken));
        // Retrieve the global platform fee
        uint256 fee = blueprint.platformFee(address(mockToken));
        // Assert that the fee is set correctly
        assertEq(fee, baseFee);
        // factor check
        assertEq(1000, blueprint.factor());
    }

    function test_updateWorkerDeploymentConfig() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));

        // set zero cost for create agents, use any number less than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), 0);

        // Create agent with token
        bytes32 requestId =
            agent.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        bytes32 updateHash =
            keccak256(abi.encodePacked(block.timestamp, address(this), requestId, base64Proposal, block.chainid));
        // Expect the UpdateDeploymentConfig event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.DeploymentConfigUpdate(projectId, requestId, workerAddress, updateHash, base64Proposal);

        // update agent deployment config
        agent.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);
    }
}
