// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "lib/forge-std/src/Test.sol";
import "../src/RouterV1.sol";
import "../src/BlueprintV7.sol";
import "../src/Agent.sol";
import {MockERC20} from "./MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {BlueprintCore} from "../src/BlueprintCore.sol";
import {Worker} from "../src/Worker.sol";

contract RouterV1Test is Test {
    RouterV1 router;
    BlueprintV7 blueprintAdmin;
    Agent agent;
    Worker worker;
    MockERC20 public mockToken;

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
        blueprintAdmin = new BlueprintV7();
        blueprintAdmin.initialize();

        // Deploy Agent with blueprint and router as trusted forwarder
        agent = new Agent(address(blueprintAdmin), address(router), router.VERSION());

        // deploy Worker contract
        worker = new Worker(address(blueprintAdmin), address(router), router.VERSION());

        // Set forward contracts in router
        router.setForwardContracts(address(agent), address(blueprintAdmin));

        // set worker
        router.setWorker(address(worker));
        // Set Agent contract in BlueprintV7 (address(this) is owner)
        blueprintAdmin.setAdminContract(address(agent));

        // set worker contract
        blueprintAdmin.setAdminContract(address(worker));

        // Deploy and mint ERC20 token
        mockToken = new MockERC20();

        // Add payment address to BlueprintV7 (address(this) is owner)
        blueprintAdmin.addPaymentAddress(address(mockToken));

        // add payment address for ETH
        blueprintAdmin.addPaymentAddress(address(0));
        // set crestal wallet address
        blueprintAdmin.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        // set agent creation and update cost into 0
        blueprintAdmin.setCreateAgentTokenCost(address(mockToken), 0);
        blueprintAdmin.setUpdateCreateAgentTokenCost(address(mockToken), 0);

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
        assertEq(blueprintAdmin.copyAgentFeeMp(requestId, address(mockToken)), 123 ether);
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

        // grant allowance to router address
        mockToken.approve(address(router), copyAgentFee);

        // Expect the CopyAgentRequest event (from Agent, which emits the same event)
        vm.expectEmit(true, false, false, false);
        emit Agent.CopyAgentRequest(copyID, requestId, address(this));

        vm.prank(relayer);
        //relayer create copy request
        router.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // check relayer balance
        assertEq(mockToken.balanceOf(relayer), 0, "Relayer should not be charged");
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
        bytes32 latestProjId = blueprintAdmin.getLatestUserProjectID(address(this));
        assertEq(projectId, latestProjId);
    }

    function testUserTopUpViaRouter() public {
        // Mint some mock tokens to the user
        uint256 topUpAmount = 100 * 10 ** 18;
        mockToken.mint(address(this), topUpAmount);

        // approve blueprint to spend user's tokens
        mockToken.approve(address(router), topUpAmount);

        // Expect the UserTopUp event
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUp(
            address(this), blueprintAdmin.feeCollectionWalletAddress(), address(mockToken), topUpAmount
        );

        // Call userTopUp via router
        router.userTopUp(address(mockToken), topUpAmount);

        // Check the user's balance in BlueprintV7
        uint256 userBalance = blueprintAdmin.userTopUpMp(address(this), address(mockToken));
        assertEq(userBalance, topUpAmount, "User top-up amount is incorrect");

        // topup eth test
        uint256 ethTopUpAmount = 1 ether;
        // Expect the UserTopUp event for ETH
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUp(address(this), blueprintAdmin.feeCollectionWalletAddress(), address(0), ethTopUpAmount);
        // Call userTopUp via router with ETH
        router.userTopUp{value: ethTopUpAmount}(address(0), ethTopUpAmount);
        // Check the user's balance in BlueprintV7 for ETH
        uint256 userEthBalance = blueprintAdmin.userTopUpMp(address(this), address(0));
        assertEq(userEthBalance, ethTopUpAmount, "User ETH top-up amount is incorrect");
    }

    function testUserTopUpOtherViaRouter() public {
        // Mint some mock tokens to the user
        uint256 topUpAmount = 100 * 10 ** 18;
        mockToken.mint(address(this), topUpAmount);

        // approve blueprint to spend user's tokens
        mockToken.approve(address(router), topUpAmount);

        // Expect the UserTopUp event
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUpOther(
            address(this), workerAddress, blueprintAdmin.feeCollectionWalletAddress(), address(mockToken), topUpAmount
        );
        // Call userTopUp via router
        router.userTopUpOther(workerAddress, address(mockToken), topUpAmount);

        // Check the user's balance in BlueprintV7
        uint256 userBalance = blueprintAdmin.userTopUpMp(workerAddress, address(mockToken));
        assertEq(userBalance, topUpAmount, "User top-up amount is incorrect");

        // topup eth test
        uint256 ethTopUpAmount = 1 ether;
        // Expect the UserTopUp event for ETH
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUpOther(
            address(this), workerAddress, blueprintAdmin.feeCollectionWalletAddress(), address(0), ethTopUpAmount
        );
        // Call userTopUp via router with ETH
        router.userTopUpOther{value: ethTopUpAmount}(workerAddress, address(0), ethTopUpAmount);
        // Check the user's balance in BlueprintV7 for ETH
        uint256 userEthBalance = blueprintAdmin.userTopUpMp(workerAddress, address(0));
        assertEq(userEthBalance, ethTopUpAmount, "User ETH top-up amount is incorrect");
    }

    function test_updateWorkerDeploymentConfigViaRouter() public {
        // create agent with token
        bytes32 requestId = router.createAgentWithToken(projectId, "base64", workerAddress, "url", address(mockToken));
        // Expect the DeploymentConfigUpdate event
        string memory newCfg = "updated";
        vm.expectEmit(true, true, true, false);
        emit BlueprintCore.DeploymentConfigUpdate(projectId, requestId, workerAddress, bytes32(0), newCfg);
        router.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, newCfg);
    }

    function test_updateWorkerDeploymentConfigWithSigViaRouter() public {
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // prepare gasless createAgent
        bytes32 cd =
            blueprintAdmin.getCreateAgentWithTokenDigest(projectId, base64, url, workerAddress, address(mockToken));
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(signerPrivateKey, cd);
        bytes memory sig0 = abi.encodePacked(r0, s0, v0);
        vm.prank(relayer);
        bytes32 requestId =
            router.createAgentWithTokenWithSig(projectId, base64, workerAddress, url, address(mockToken), sig0);

        // prepare gasless update
        string memory newCfg = "cfgSig";
        uint256 nonceBefore = blueprintAdmin.getUserNonce(owner);
        bytes32 ud =
            blueprintAdmin.getUpdateWorkerConfigDigest(address(mockToken), projectId, requestId, newCfg, nonceBefore);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(signerPrivateKey, ud);
        bytes memory sig1 = abi.encodePacked(r1, s1, v1);

        vm.expectEmit(true, true, true, false);
        emit BlueprintCore.DeploymentConfigUpdate(projectId, requestId, owner, bytes32(0), newCfg);
        vm.prank(relayer);
        router.updateWorkerDeploymentConfigWithSig(address(mockToken), projectId, requestId, newCfg, sig1);

        assertEq(blueprintAdmin.getUserNonce(owner), nonceBefore + 1);
    }

    function test_createAgentWithTokenWithSigViaRouter() public {
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // prepare gasless createAgent digest & sig
        bytes32 cd =
            blueprintAdmin.getCreateAgentWithTokenDigest(projectId, base64, url, workerAddress, address(mockToken));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, cd);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(relayer);
        bytes32 requestId =
            router.createAgentWithTokenWithSig(projectId, base64, workerAddress, url, address(mockToken), sig);

        assertTrue(requestId != bytes32(0), "requestId must be non-zero");
        // check that blueprint recorded the new project for the owner
        bytes32 latest = blueprintAdmin.getLatestUserProjectID(owner);
        assertEq(latest, projectId, "projectId not recorded");
    }

    function test_setCopyAgentFeeWithSigViaRouter() public {
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // create agent by meta-tx so deploymentOwner == owner
        bytes32 cd =
            blueprintAdmin.getCreateAgentWithTokenDigest(projectId, base64, url, workerAddress, address(mockToken));
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(signerPrivateKey, cd);
        bytes memory sig0 = abi.encodePacked(r0, s0, v0);
        vm.prank(relayer);
        bytes32 requestId =
            router.createAgentWithTokenWithSig(projectId, base64, workerAddress, url, address(mockToken), sig0);

        uint256 fee = 1000;
        uint256 nonceBefore = blueprintAdmin.getUserNonce(owner);

        // prepare meta-tx for setCopyAgentFee
        bytes32 fd = blueprintAdmin.getSetCopyAgentFeeDigest(requestId, address(mockToken), fee, nonceBefore);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(signerPrivateKey, fd);
        bytes memory sig1 = abi.encodePacked(r1, s1, v1);

        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, owner, address(mockToken), fee);

        vm.prank(relayer);
        router.setCopyAgentFeeWithSig(requestId, address(mockToken), fee, sig1);

        // state change
        uint256 stored = blueprintAdmin.copyAgentFeeMp(requestId, address(mockToken));
        assertEq(stored, fee, "fee not stored");
        assertEq(blueprintAdmin.getUserNonce(owner), nonceBefore + 1, "nonce not incremented");
    }

    function test_createCopyAgentRequestWithSigViaRouter() public {
        address user = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // address this create agent and then user create a copy request
        bytes32 requestId = router.createAgentWithToken(projectId, base64, workerAddress, url, address(mockToken));

        // set copy-fee normally (owner can call)
        uint256 copyFee = 1234;
        router.setCopyAgentFee(requestId, address(mockToken), copyFee);

        // prepare create-copy digest & sig
        bytes32 copyID = keccak256(abi.encodePacked(block.timestamp, relayer, requestId, base64, block.chainid));
        bytes32 crd = blueprintAdmin.getCreateCopyAgentRequestDigest(copyID, requestId, address(mockToken));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signerPrivateKey, crd);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);

        // fund & approve user
        mockToken.mint(user, copyFee);
        vm.prank(user);
        mockToken.approve(address(router), copyFee);

        // user balance before
        assertEq(mockToken.balanceOf(user), copyFee, "owner should have enough tokens");

        vm.expectEmit(true, true, false, false);
        emit Agent.CopyAgentRequest(copyID, requestId, user);

        // user create copy agent request via relayer
        vm.prank(relayer);
        router.createCopyAgentRequestWithSig(copyID, requestId, address(mockToken), sig2);

        // relayer balance unchanged
        assertEq(mockToken.balanceOf(relayer), 0, "relayer should not be charged");
        // user balance should be reduced by copyFee
        assertEq(mockToken.balanceOf(user), 0, "owner should be charged");
    }

    function test_getEIP712ContractAddress_via_router() public view {
        address fromBlueprint = blueprintAdmin.getEIP712ContractAddress();
        address viaRouter = router.getEIP712ContractAddress();
        assertEq(viaRouter, fromBlueprint);
    }

    function test_getPaymentOpCost_via_router() public {
        // set custom costs
        blueprintAdmin.setCreateAgentTokenCost(address(mockToken), 42);
        blueprintAdmin.setUpdateCreateAgentTokenCost(address(mockToken), 84);

        uint256 c1 = router.getPaymentOpCost(address(mockToken), blueprintAdmin.CREATE_AGENT_OP());
        uint256 c2 = router.getPaymentOpCost(address(mockToken), blueprintAdmin.UPDATE_AGENT_OP());

        assertEq(c1, 42);
        assertEq(c2, 84);
    }

    function test_getBlueprintVersion_via_router() public view {
        string memory v0 = blueprintAdmin.VERSION();
        string memory v1 = router.getBlueprintVersion();
        assertEq(v1, v0);
    }

    function test_getDeploymentOwner_via_router() public {
        // create an agent and then query owner
        bytes32 req = router.createAgentWithToken(projectId, "foo", workerAddress, "url", address(mockToken));
        address owner = router.getDeploymentOwner(req);
        assertEq(owner, address(this));
    }

    function test_getUserNonce_initial_and_after_increment() public {
        address u = address(0x123);
        // initial
        assertEq(router.getUserNonce(u), 0);

        // only agent contract can call incrementUserNonce
        vm.prank(address(agent));
        // bump in blueprint directly
        blueprintAdmin.incrementUserNonce(u);
        assertEq(router.getUserNonce(u), 1);
    }

    function test_getPaymentAddresses_via_router() public view {
        // setUp already added mockToken and address(0)
        address[] memory pays = router.getPaymentAddresses();
        assertEq(pays.length, 2);
        assertEq(pays[0], address(mockToken));
        assertEq(pays[1], address(0));
    }

    function test_getWorkerAddresses_and_publicKey_via_router() public {
        // initially empty
        address[] memory w = router.getWorkerAddresses();
        assertEq(w.length, 0);

        // set trusted worker address
        blueprintAdmin.updateWorker(workerAddress, true);

        vm.prank(workerAddress);
        // register a worker public key
        bytes memory pubKey = "public key";
        router.setWorkerPublicKey(pubKey);

        // public key for nonexistent worker
        bytes memory key = router.getWorkerPublicKey(workerAddress);
        assertEq(keccak256(key), keccak256(bytes(pubKey)), "Public key mismatch");
    }

    function test_getLatestDeploymentRequestID_via_router() public {
        // create deployment to populate latestDeploymentRequestID
        bytes32 req = router.createAgentWithToken(projectId, "foo", workerAddress, "url", address(mockToken));
        bytes32 got = router.getLatestDeploymentRequestID(address(this));
        assertEq(got, req);
    }

    function test_setWorkerPublicKey_via_router() public {
        // enable the worker in blueprint
        blueprintAdmin.updateWorker(workerAddress, true);

        bytes memory pubKey = "router-key";
        vm.prank(workerAddress);
        router.setWorkerPublicKey(pubKey);

        // verify stored public key and address list
        bytes memory got = router.getWorkerPublicKey(workerAddress);
        assertEq(keccak256(got), keccak256(pubKey), "public key mismatch");

        address[] memory addrs = router.getWorkerAddresses();
        assertEq(addrs[addrs.length - 1], workerAddress, "worker address not registered");
    }

    function test_submitDeploymentRequest_via_router() public {
        // create a public deployment request (workerAddress = address(0))
        bytes32 reqId = router.createAgentWithToken(projectId, "proposal", address(0), "url", address(mockToken));

        // enable the worker
        blueprintAdmin.updateWorker(workerAddress, true);

        // expect AcceptDeployment event from blueprint
        vm.expectEmit(true, true, true, false);
        emit BlueprintCore.AcceptDeployment(projectId, reqId, workerAddress);

        vm.prank(workerAddress);
        bool accepted = router.submitDeploymentRequest(projectId, reqId);
        assertTrue(accepted, "deployment not accepted");

        // verify status and assigned worker
        (BlueprintCore.Status st, address w) = blueprintAdmin.getDeploymentStatus(reqId);
        assertEq(uint256(st), uint256(BlueprintCore.Status.Pickup), "wrong status");
        assertEq(w, workerAddress, "wrong worker assigned");
    }

    function test_submitProofOfDeployment_via_router() public {
        // create public request and claim it
        bytes32 reqId = router.createAgentWithToken(projectId, "proposal", address(0), "url", address(mockToken));
        blueprintAdmin.updateWorker(workerAddress, true);
        vm.prank(workerAddress);
        router.submitDeploymentRequest(projectId, reqId);

        // expect GeneratedProofOfDeployment event
        string memory proof = "proof-data";
        vm.expectEmit(true, true, false, false);
        emit BlueprintCore.GeneratedProofOfDeployment(projectId, reqId, proof);

        vm.prank(workerAddress);
        router.submitProofOfDeployment(projectId, reqId, proof);

        // verify stored proof and status
        string memory got = blueprintAdmin.getDeploymentProof(reqId);
        assertEq(got, proof, "proof mismatch");

        (BlueprintCore.Status st,) = blueprintAdmin.getDeploymentStatus(reqId);
        assertEq(uint256(st), uint256(BlueprintCore.Status.GeneratedProof), "status not updated");
    }
}
