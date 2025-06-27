pragma solidity ^0.8.26;

import "../src/RouterV1.sol";
import {Agent} from "../src/Agent.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import {MockERC20} from "./MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdError} from "forge-std/StdError.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IRouterV1} from "../src/IRouter.sol";

contract AgentTest is Test {
    IRouterV1 iRouter;
    RouterV1 router;
    Agent public agent;
    MockERC20 public mockToken;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        // Deploy MockERC20
        mockToken = new MockERC20();

        // Deploy RouterV1
        router = new RouterV1();
        router.initialize(); // mimic upgradeable contract deploy behavior

        // Deploy BlueprintV7
        BlueprintV7 blueprint = new BlueprintV7();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        // deploy agent
        agent = new Agent("1.0.0");

        // set agent and blueprint in router
        router.setAgent(address(agent));

        bytes4[] memory agentSelectors = new bytes4[](7);
        agentSelectors[0] = bytes4(keccak256("setCopyAgentFee(bytes32,address,uint256)"));
        agentSelectors[1] = bytes4(keccak256("setCopyAgentFeeWithSig(bytes32,address,uint256,bytes)"));
        agentSelectors[2] = bytes4(keccak256("createCopyAgentRequest(bytes32,bytes32,address)"));
        agentSelectors[3] = bytes4(keccak256("createCopyAgentRequestWithSig(bytes32,bytes32,address,bytes)"));
        agentSelectors[4] = bytes4(keccak256("getCreateCopyAgentFee(bytes32,address)"));
        agentSelectors[5] = bytes4(keccak256("userTopUp(address,uint256)"));
        agentSelectors[6] = bytes4(keccak256("userTopUpOther(address,address,uint256)"));

        router.setSelectorTargets(agentSelectors, address(agent));

        // set blueprint in agent
        router.setBlueprint(address(blueprint));
        router.setBlueprintAdmin(address(this));

        // add admin config info
        iRouter = IRouterV1(address(router));

        // Add payment address to BlueprintV7 (address(this) is owner)
        iRouter.addPaymentAddress(address(mockToken));

        // add payment address for ETH
        iRouter.addPaymentAddress(address(0));
        // set crestal wallet address
        iRouter.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        // set agent creation and update cost into 0
        iRouter.setCreateAgentTokenCost(address(mockToken), 0);
        iRouter.setUpdateCreateAgentTokenCost(address(mockToken), 0);

        // set factor
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
    }

    function test_setCopyAgentFee() public {
        bytes32 requestId = iRouter.createAgentWithToken(projectId, "test", workerAddress, "test", address(mockToken));

        // set copy agent fee to 1000
        uint256 copyAgentFee = 1000;

        // Expect the CopyAgentFeeSet event (from Agent, which emits the same event)
        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, address(this), address(mockToken), copyAgentFee);

        iRouter.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // get the copy agent fee from Blueprint
        uint256 copyFee = router.copyAgentFeeMp(requestId, address(mockToken));

        // Assert that the copy agent fee is set correctly
        assertEq(copyFee, copyAgentFee);

        // invalid request id
        bytes32 invalidRequestId = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        // Expect the transaction to revert with the correct error message
        vm.expectRevert("Not owner");
        iRouter.setCopyAgentFee(invalidRequestId, address(mockToken), copyAgentFee);
    }

    function test_createCopyAgentRequest() public {
        // set copy agent fee to 1000
        uint256 copyAgentFee = 10; // 10 percent
        uint256 baseFee = 1000000; // 100000 token

        bytes32 requestId = iRouter.createAgentWithToken(projectId, "test", workerAddress, "test", address(mockToken));
        // generate copy agent request ID
        bytes32 copyID =
            keccak256(abi.encodePacked(uint256(block.timestamp), address(this), requestId, "", block.chainid));

        // creator not set copy fee
        vm.expectRevert("Platform fee is not set");
        iRouter.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // set platform fee
        iRouter.setGlobalPlatformFee(baseFee, address(mockToken));

        // set copy agent fee
        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, address(this), address(mockToken), copyAgentFee);
        iRouter.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // sender not have any erc20 token error
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        iRouter.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // transfer some mock tokens to the sender
        uint256 totalFee = iRouter.getCreateCopyAgentFee(requestId, address(mockToken));
        mockToken.mint(address(this), totalFee);

        // revert: not grant allowance to Agent contract
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        iRouter.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // grant allowance to iRouter address
        mockToken.approve(address(iRouter), totalFee);

        // owner cannot create copy agent request
        vm.expectRevert("Cannot transfer to self address");
        iRouter.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // transfer some mock tokens to relayer
        address relayer = address(0xBEEF);
        mockToken.mint(relayer, totalFee);
        vm.prank(relayer);

        // grant allowance to blueprint address
        mockToken.approve(address(iRouter), totalFee);

        uint256 platformFee = router.platformFee(address(mockToken));
        uint256 creatorFee = (copyAgentFee * platformFee) / router.factor();

        // Expect the CopyAgentRequest event (from Agent, which emits the same event)
        vm.expectEmit(true, false, false, false);
        emit Agent.CopyAgentRequest(copyID, requestId, address(this), platformFee + creatorFee);

        // creator balance before creating copy agent request
        uint256 creatorBalanceBefore = mockToken.balanceOf(address(this));

        vm.prank(relayer);
        // Create copy agent request
        iRouter.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // check fee collect wallet balance and creator balance
        uint256 feeCollectionWalletBalance = mockToken.balanceOf(router.feeCollectionWalletAddress());
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
        bytes32 createAgentDigest = iRouter.getCreateAgentWithTokenDigest(
            projectId, base64Proposal, serverURL, workerAddress, address(mockToken)
        );
        (uint8 vA, bytes32 rA, bytes32 sA) = vm.sign(signerPrivateKey, createAgentDigest);
        bytes memory createAgentSig = abi.encodePacked(rA, sA, vA);
        // Call createAgentWithTokenWithSig as relayer
        vm.prank(relayer);
        bytes32 requestId = iRouter.createAgentWithTokenWithSig(
            projectId, base64Proposal, workerAddress, serverURL, address(mockToken), createAgentSig
        );
        // Set copy agent fee using gasless signature
        uint256 copyAgentFee = 100; // 100 / 1000(factor) percent
        uint256 nonce = iRouter.getUserNonce(owner);
        bytes32 digest = iRouter.getSetCopyAgentFeeDigest(requestId, address(mockToken), copyAgentFee, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        // Expect event
        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, owner, address(mockToken), copyAgentFee);
        // Call as relayer (not owner)
        vm.prank(relayer);
        iRouter.setCopyAgentFeeWithSig(requestId, address(mockToken), copyAgentFee, signature);
        // Check state
        uint256 copyFee = router.copyAgentFeeMp(requestId, address(mockToken));
        assertEq(copyFee, copyAgentFee);
    }

    function test_createCopyAgentRequestWithSig() public {
        address user = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        // Mint and approve tokens for owner (not relayer)
        uint256 copyAgentFee = 100; // 100 / 1000 (factor) percent
        uint256 baseFee = 1000000; // 100000 token
        uint256 factor = router.factor();
        uint256 totalFee = baseFee + (copyAgentFee * baseFee) / factor;
        // Set the global platform fee
        iRouter.setGlobalPlatformFee(baseFee, address(mockToken)); // 100000 token

        //  0 cost, no need to set allowance and mint tokens
        // Create agent with token, owner is address(this)
        bytes32 requestId =
            iRouter.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // Set copy agent fee as owner
        iRouter.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        // Generate copyID
        bytes32 copyID =
            keccak256(abi.encodePacked(uint256(block.timestamp), relayer, requestId, base64Proposal, block.chainid));

        // Owner signs the createCopyAgentRequest digest
        bytes32 digest = iRouter.getCreateCopyAgentRequestDigest(copyID, requestId, address(mockToken));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Mint and approve tokens for owner (not relayer)
        mockToken.mint(user, totalFee);
        vm.prank(user);
        mockToken.approve(address(iRouter), totalFee);

        // Record balances before
        uint256 ownerBalanceBefore = mockToken.balanceOf(user);

        // Expect event
        vm.expectEmit(true, true, true, false);
        emit Agent.CopyAgentRequest(copyID, requestId, user, totalFee);

        // Relayer submits the gasless request
        vm.prank(relayer);
        iRouter.createCopyAgentRequestWithSig(copyID, requestId, address(mockToken), signature);

        // Check relayer balance is unchanged (should be 0)
        assertEq(mockToken.balanceOf(relayer), 0, "Relayer balance should be 0 after gasless copy agent request");
        // Check owner's balance is reduced by the fee
        assertEq(mockToken.balanceOf(user), ownerBalanceBefore - totalFee, "Owner should pay the copy agent fee");
    }
}
