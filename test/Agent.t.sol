pragma solidity ^0.8.26;

import "../src/RouterV1.sol";
import {Agent} from "../src/Agent.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {MockERC20} from "./MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/StdError.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AgentTest is Test {
    RouterV1 router;
    BlueprintV7 public blueprint;
    Agent public agent;
    MockERC20 public mockToken;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        RouterV1 impl = new RouterV1();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
        router = RouterV1(address(proxy));
        router.initialize();

        blueprint = new BlueprintV7();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        agent = new Agent(address(blueprint), address(router));

        // Set forward contracts in router
        router.setForwardContracts(address(agent), address(blueprint));

        // Set the agent contract address in Blueprint
        blueprint.setAgentContract(address(agent));

        mockToken = new MockERC20();

        // set crestal wallet address
        blueprint.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));

        // set zero cost for create agents, use any number less than 0
        blueprint.setCreateAgentTokenCost(address(mockToken), 0);

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
    }

    function test_setCopyAgentFee() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Expect revert because agentContract is not set in Blueprint
        //        vm.expectRevert("Only Agent contract allow");
        //        agent.setCopyAgentFee(projectId, address(mockToken), 12);

        // Create agent with token
        bytes32 requestId =
            agent.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // set copy agent fee to 1000
        uint256 copyAgentFee = 1000;

        // Expect the CopyAgentFeeSet event (from Agent, which emits the same event)
        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, address(this), address(mockToken), copyAgentFee);

        agent.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // get the copy agent fee from Blueprint
        uint256 copyFee = blueprint.copyAgentFeeMp(requestId, address(mockToken));

        // Assert that the copy agent fee is set correctly
        assertEq(copyFee, copyAgentFee);

        // invalid request id
        bytes32 invalidRequestId = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        // Expect the transaction to revert with the correct error message
        vm.expectRevert("Not owner");
        agent.setCopyAgentFee(invalidRequestId, address(mockToken), copyAgentFee);
    }

    function test_createCopyAgentRequest() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Create agent with token
        bytes32 requestId =
            agent.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // set copy agent fee to 1000
        uint256 copyAgentFee = 1000;

        // Expect revert because agentContract is not set in Blueprint
        //        vm.expectRevert("Only Agent contract allow");
        //        agent.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // Set the agent contract address in Blueprint
        //        blueprint.setAgentContract(address(agent));

        // generate copy agent request ID
        bytes32 copyID = keccak256(
            abi.encodePacked(uint256(block.timestamp), address(this), requestId, base64Proposal, block.chainid)
        );

        // creator not set copy fee
        vm.expectRevert("Copy Agent is not set by the owner");
        agent.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // set copy agent fee
        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, address(this), address(mockToken), copyAgentFee);
        agent.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // sender not have any erc20 token error
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        agent.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // transfer some mock tokens to the sender
        mockToken.mint(address(this), copyAgentFee);

        // revert: not grant allowance to Agent contract
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        agent.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // grant allowance to blueprint address
        mockToken.approve(address(blueprint), copyAgentFee);

        // owner cannot create copy agent request
        vm.expectRevert("Cannot transfer to self address");
        agent.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // transfer some mock tokens to relayer
        address relayer = address(0xBEEF);
        mockToken.mint(relayer, copyAgentFee);
        vm.prank(relayer);

        // grant allowance to blueprint address
        mockToken.approve(address(blueprint), copyAgentFee);

        // Expect the CopyAgentRequest event (from Agent, which emits the same event)
        vm.expectEmit(true, false, false, false);
        emit Agent.CopyAgentRequest(copyID, requestId, address(this));

        // creator balance before creating copy agent request
        uint256 creatorBalanceBefore = mockToken.balanceOf(address(this));

        vm.prank(relayer);
        // Create copy agent request
        agent.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // check fee collect wallet balance and creator balance
        uint256 platformFee = (copyAgentFee * blueprint.platformCopyAgentFee()) / blueprint.factor();
        uint256 creatorFee = copyAgentFee - platformFee;
        uint256 feeCollectionWalletBalance = mockToken.balanceOf(blueprint.feeCollectionWalletAddress());
        // creator balance after creating copy agent request
        uint256 creatorBalanceAfter = mockToken.balanceOf(address(this));
        // Assert that the platform fee is collected correctly
        assertEq(feeCollectionWalletBalance, platformFee, "Platform fee not collected correctly");
        // Assert that the creator fee is transferred correctly
        assertEq(creatorFee, creatorBalanceAfter - creatorBalanceBefore, "Creator fee not transferred correctly");
        // check relayer balance
        uint256 relayerBalance = mockToken.balanceOf(relayer);
        // should be 0
        assertEq(relayerBalance, 0, "Relayer balance should be 0 after creating copy agent request");
    }

    function test_setCopyAgentFeeWithSig() public {
        // Setup: use a real owner (not address(this)), derived from signerPrivateKey
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        //  0 cost, no need to set allowance and mint tokens
        // Prepare EIP-712 digest for createAgentWithToken
        bytes32 createAgentDigest = blueprint.getCreateAgentWithTokenDigest(
            projectId, base64Proposal, serverURL, workerAddress, address(mockToken)
        );
        (uint8 vA, bytes32 rA, bytes32 sA) = vm.sign(signerPrivateKey, createAgentDigest);
        bytes memory createAgentSig = abi.encodePacked(rA, sA, vA);
        // Call createAgentWithTokenWithSig as relayer
        vm.prank(relayer);
        bytes32 requestId = agent.createAgentWithTokenWithSig(
            projectId, base64Proposal, workerAddress, serverURL, address(mockToken), createAgentSig
        );
        // Set copy agent fee using gasless signature
        uint256 copyAgentFee = 1000;
        uint256 nonce = blueprint.getUserNonce(owner);
        bytes32 digest = blueprint.getSetCopyAgentFeeDigest(requestId, address(mockToken), copyAgentFee, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        // Expect event
        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, owner, address(mockToken), copyAgentFee);
        // Call as relayer (not owner)
        vm.prank(relayer);
        agent.setCopyAgentFeeWithSig(requestId, address(mockToken), copyAgentFee, signature);
        // Check state
        uint256 copyFee = blueprint.copyAgentFeeMp(requestId, address(mockToken));
        assertEq(copyFee, copyAgentFee);
    }

    function test_createCopyAgentRequestWithSig() public {
        address user = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Mint and approve tokens for owner (not relayer)
        uint256 copyAgentFee = 1000;
        //  0 cost, no need to set allowance and mint tokens
        // Create agent with token, owner is address(this)
        bytes32 requestId =
            agent.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // Set copy agent fee as owner
        agent.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // Generate copyID
        bytes32 copyID =
            keccak256(abi.encodePacked(uint256(block.timestamp), relayer, requestId, base64Proposal, block.chainid));

        // Owner signs the createCopyAgentRequest digest
        bytes32 digest = blueprint.getCreateCopyAgentRequestDigest(copyID, requestId, address(mockToken));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Mint and approve tokens for owner (not relayer)
        mockToken.mint(user, copyAgentFee);
        vm.prank(user);
        mockToken.approve(address(blueprint), copyAgentFee);

        // Record balances before
        uint256 ownerBalanceBefore = mockToken.balanceOf(user);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit Agent.CopyAgentRequest(copyID, requestId, user);

        // Relayer submits the gasless request
        vm.prank(relayer);
        agent.createCopyAgentRequestWithSig(copyID, requestId, address(mockToken), signature);

        // Check relayer balance is unchanged (should be 0)
        assertEq(mockToken.balanceOf(relayer), 0, "Relayer balance should be 0 after gasless copy agent request");
        // Check owner's balance is reduced by the fee
        assertEq(mockToken.balanceOf(user), ownerBalanceBefore - copyAgentFee, "Owner should pay the copy agent fee");
    }
}
