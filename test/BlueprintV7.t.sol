pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {BlueprintCore} from "../src/BlueprintCore.sol";
import {Blueprint} from "../src/Blueprint.sol";
import {stdError} from "forge-std/StdError.sol";
import {MockERC20} from "./MockERC20.sol";

contract BlueprintTest is Test {
    BlueprintV7 public blueprint;
    MockERC20 public mockToken;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        blueprint = new BlueprintV7();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        mockToken = new MockERC20();

        // set crestal wallet address
        blueprint.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
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
            blueprint.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // set zero cost for create agents, use any number less than 0
        blueprint.setUpdateCreateAgentTokenCost(address(mockToken), 0);

        bytes32 updateHash =
            keccak256(abi.encodePacked(block.timestamp, address(this), requestId, base64Proposal, block.chainid));
        // Expect the UpdateDeploymentConfig event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.DeploymentConfigUpdate(projectId, requestId, workerAddress, updateHash, base64Proposal);

        // update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);
    }
}
