pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV5} from "../src/BlueprintV5.sol";
import {BlueprintCore} from "../src/BlueprintCore.sol";
import {stdError} from "forge-std/StdError.sol";
import {MockERC20} from "./MockERC20.sol";

contract BlueprintTest is Test {
    BlueprintV5 public blueprint;
    MockERC20 public mockToken;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;

    function setUp() public {
        blueprint = new BlueprintV5();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        mockToken = new MockERC20();
        blueprint.addPaymentAddress(address(mockToken));

        // set crestal wallet address
        blueprint.setCrestalWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
    }

    function test_createAgentWithToken() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "http://example.com";

        // Generate the signature
        (bytes memory signature, address signerAddress) = generateSignature(projectId, base64Proposal, serverURL);

        // set zero cost for create agents, use any number less than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), -1);

        // Expect the createAgent event
        vm.expectEmit(true, false, true, true);
        emit BlueprintCore.CreateAgent(projectId, "fake", signerAddress, 0, 0);

        // Create agent with token
        blueprint.createAgentWithTokenWithSig(
            projectId, base64Proposal, workerAddress, serverURL, address(mockToken), signature
        );

        bytes32 latestProjId = blueprint.getLatestUserProjectID(signerAddress);
        assertEq(projectId, latestProjId);

        // Mint tokens to the test account
        int256 validTokenAmount = 100 * 10 ** 18;

        // set none zero cost for create agents, use any number greater than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), validTokenAmount);

        mockToken.mint(address(this), uint256(validTokenAmount));

        // Verify the mint
        uint256 balance = mockToken.balanceOf(address(this));
        assertEq(balance, uint256(validTokenAmount), "sender does not have the correct token balance");

        // check LogApproveEvent
        vm.expectEmit(true, true, false, true);
        emit MockERC20.LogApproval(address(this), address(blueprint), uint256(validTokenAmount));

        // Approve the blueprint contract to spend tokens directly from the test contract
        mockToken.approve(address(blueprint), uint256(validTokenAmount));

        // check allowance after approve
        uint256 allowance = mockToken.allowance(address(this), address(blueprint));
        assertEq(allowance, uint256(validTokenAmount), "sender does not have the correct token allowance");

        // try with different project id
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2981);
        // create agent with token and non zero cost
        blueprint.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // check balance after creation, it should be balance - cost
        balance = mockToken.balanceOf(address(this));
        assertEq(balance, 0, "signer does not have the correct token balance after creation");
    }

    function test_Revert_createAgentWithToken() public {
        // not set agent creation operation
        vm.expectRevert("Token address is invalid");
        blueprint.createAgentWithToken(
            projectId, "test base64 proposal", workerAddress, "http://example.com", address(mockToken)
        );

        // Mint tokens to the test account
        int256 validTokenAmount = 100 * 10 ** 18;

        // set none zero cost for create agents, use any number greater than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), validTokenAmount);

        // not enough balance to create agent
        vm.expectRevert("Insufficient balance");
        blueprint.createAgentWithToken(
            projectId, "test base64 proposal", workerAddress, "http://example.com", address(mockToken)
        );

        // Mint tokens to the test account
        mockToken.mint(address(this), uint256(validTokenAmount));

        // not approve blueprint to spend token
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        blueprint.createAgentWithToken(
            projectId, "test base64 proposal", workerAddress, "http://example.com", address(mockToken)
        );

        // Approve the blueprint contract to spend tokens directly from the test contract
        mockToken.approve(address(blueprint), uint256(validTokenAmount - 1));

        // not enough allowance to create agent
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        blueprint.createAgentWithToken(
            projectId, "test base64 proposal", workerAddress, "http://example.com", address(mockToken)
        );
    }

    function test_updateWorkerDeploymentConfig() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // set zero cost for create agents, use any number less than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), -1);

        // Create agent with token
        bytes32 requestId =
            blueprint.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // set zero cost for create agents, use any number less than 0
        blueprint.setUpdateCreateAgentTokenCost(address(mockToken), -1);

        // Expect the UpdateDeploymentConfig event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.UpdateDeploymentConfig(projectId, requestId, workerAddress, base64Proposal);

        // update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);

        int256 validTokenAmount = 100 * 10 ** 18;

        // Set the cost for updating the deployment config
        blueprint.setUpdateCreateAgentTokenCost(address(mockToken), validTokenAmount);

        // Mint tokens to the test account
        mockToken.mint(address(this), uint256(validTokenAmount));

        // Approve the blueprint contract to spend tokens
        mockToken.approve(address(blueprint), uint256(validTokenAmount));

        // Expect the UpdateDeploymentConfig event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.UpdateDeploymentConfig(projectId, requestId, workerAddress, base64Proposal);

        //  update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);
    }

    function test_Revert_updateWorkerDeploymentConfig() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // set zero cost for create agents, use any number less than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), -1);

        // Create agent with token
        bytes32 requestId =
            blueprint.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // not set agent update operation
        vm.expectRevert("Invalid token address");
        //  update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);

        // Mint tokens to the test account
        int256 validTokenAmount = 100 * 10 ** 18;

        // set none zero cost for create agents, use any number greater than 0
        blueprint.setUpdateCreateAgentTokenCost(address(mockToken), validTokenAmount);

        // not enough balance to create agent
        vm.expectRevert("Insufficient balance");
        //  update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);

        // Mint tokens to the test account
        mockToken.mint(address(this), uint256(validTokenAmount));

        // not approve blueprint to spend token
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        //  update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);

        // Approve the blueprint contract to spend tokens directly from the test contract
        mockToken.approve(address(blueprint), uint256(validTokenAmount - 1));

        // not enough allowance to create agent
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        //  update agent deployment config
        blueprint.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, base64Proposal);
    }

    function generateSignature(bytes32 _projectId, string memory _base64Proposal, string memory _serverURL)
        internal
        view
        returns (bytes memory, address)
    {
        bytes32 digest = blueprint.getRequestDeploymentDigest(_projectId, _base64Proposal, _serverURL);
        uint256 signerPrivateKey = 0xA11CE;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return (abi.encodePacked(r, s, v), vm.addr(0xA11CE));
    }
}
