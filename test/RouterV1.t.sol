// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "lib/forge-std/src/Test.sol";
import "../src/RouterV1.sol";
import {BlueprintV1} from "../src/BlueprintV1.sol";
import {BlueprintV2} from "../src/BlueprintV2.sol";
import {BlueprintV3} from "../src/BlueprintV3.sol";
import {BlueprintV4} from "../src/BlueprintV4.sol";
import {BlueprintV5} from "../src/BlueprintV5.sol";
import {BlueprintV6} from "../src/BlueprintV6.sol";
import {BlueprintV7} from "../src/BlueprintV7.sol";
import "../src/Agent.sol";
import {MockERC20} from "./MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NewBlueprintCore} from "../src/NewBlueprintCore.sol";
import {IRouterV1} from "../src/IRouter.sol";
import {NewBlueprint} from "../src/NewBlueprint.sol";
import {Storage} from "../src/Storage.sol";

// Add this interface declaration
interface IERC1967 {
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract RouterV1Test is Test {
    Agent agent;
    MockERC20 public mockToken;
    IRouterV1 iRouter;
    RouterV1 router;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        // init variables
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
        uint256 baseFee = 1000; // 1000 nation token

        // Deploy the initial BlueprintV1 contract
        BlueprintV1 blueprintV1 = new BlueprintV1();

        // Create a proxy pointing to the implementation
        ERC1967Proxy e1967 = new ERC1967Proxy(address(blueprintV1), abi.encodeWithSignature("initialize()"));

        // Interact with the proxy as if it were the implementation
        BlueprintV1 proxy = BlueprintV1(address(e1967));

        // Upgrade the proxy to from V2 to V7
        BlueprintV2 blueprintV2 = new BlueprintV2();
        proxy.upgradeToAndCall(address(blueprintV2), abi.encodeWithSignature("initialize()"));

        BlueprintV3 blueprintV3 = new BlueprintV3();
        proxy.upgradeToAndCall(address(blueprintV3), abi.encodeWithSignature("initialize()"));

        BlueprintV4 blueprintV4 = new BlueprintV4();
        proxy.upgradeToAndCall(address(blueprintV4), abi.encodeWithSignature("initialize()"));

        BlueprintV5 blueprintV5 = new BlueprintV5();
        proxy.upgradeToAndCall(address(blueprintV5), abi.encodeWithSignature("initialize()"));

        BlueprintV6 blueprintV6 = new BlueprintV6();
        proxy.upgradeToAndCall(address(blueprintV6), abi.encodeWithSignature("initialize()"));

        BlueprintV7 blueprintV7 = new BlueprintV7();
        proxy.upgradeToAndCall(address(blueprintV7), abi.encodeWithSignature("initialize()"));


        BlueprintV7 blueprintAdmin = BlueprintV7(address(proxy));
        // do some setting before convert into router proxy
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

        // set the global platform fee
        blueprintAdmin.setGlobalPlatformFee(baseFee, address(mockToken));

        // 3. Check and transfer ownership if needed
        address owner = OwnableUpgradeable(address(proxy)).owner();
        console.log("Proxy Owner:", owner);

        assertEq(owner, address(this), "Proxy owner should be this contract");
        RouterV1 routerImpl = new RouterV1();
        //
        (bool ok, bytes memory ret) = address(routerImpl).call(abi.encodeWithSignature("proxiableUUID()"));
        console.log("RouterV1 proxiableUUID exists?", ok);

        if (ok) {
            bytes32 slot;
            assembly {
                slot := mload(add(ret, 32))
            }
            console.logBytes32(slot);
            require(
                slot == 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc,
                "RouterV1 returns wrong UUID"
            );
        } else {
            revert("RouterV1 does not implement proxiableUUID()");
        }

        // 3. Tell the proxy to point to V2
        IERC1967(address(proxy)).upgradeToAndCall(address(routerImpl), "");

        router = RouterV1(payable(address(proxy)));

        // deploy agent contract
        agent = new Agent(router.VERSION());

        // Set Agent contract in router
        router.setAgent(address(agent));

        // deploy blueprint contract
        NewBlueprint blueprint = new NewBlueprint(router.VERSION());

        // set Blueprint contract in router
        router.setBlueprint(address(blueprint));

        // set blueprint admin
        router.setBlueprintAdmin(address(this));

        bytes4[] memory agentSelectors = new bytes4[](7);
        agentSelectors[0] = bytes4(keccak256("setCopyAgentFee(bytes32,address,uint256)"));
        agentSelectors[1] = bytes4(keccak256("setCopyAgentFeeWithSig(bytes32,address,uint256,bytes)"));
        agentSelectors[2] = bytes4(keccak256("createCopyAgentRequest(bytes32,bytes32,address)"));
        agentSelectors[3] = bytes4(keccak256("createCopyAgentRequestWithSig(bytes32,bytes32,address,bytes)"));
        agentSelectors[4] = bytes4(keccak256("getCreateCopyAgentFee(bytes32,address)"));
        agentSelectors[5] = bytes4(keccak256("userTopUp(address,uint256)"));
        agentSelectors[6] = bytes4(keccak256("userTopUpOther(address,address,uint256)"));

        router.setSelectorTargets(agentSelectors, address(agent));

        // cast to interface
        iRouter = IRouterV1(address(router));
    }

    function testSetCopyAgentFeeViaRouter() public {
        bytes32 requestId =
            iRouter.createAgentWithToken(projectId, "base64", workerAddress, "serverURL", address(mockToken));

        // check setCopyAgentFee event
        vm.expectEmit(true, true, true, false);
        emit Agent.SetCopyAgentFee(requestId, address(this), address(mockToken), 123 ether);
        // Call setCopyAgentFee via router as deployment owner
        iRouter.setCopyAgentFee(requestId, address(mockToken), 123 ether);
    }

    function testCreateCopyAgentRequestViaRouter() public {
        bytes32 requestId =
            iRouter.createAgentWithToken(projectId, "base64", workerAddress, "serverURL", address(mockToken));

        uint256 copyAgentFee = 100; // 10 percent: 100 / 1000 (factor)

        // Set copy agent fee
        iRouter.setCopyAgentFee(requestId, address(mockToken), copyAgentFee);

        uint256 totalFee = iRouter.getCreateCopyAgentFee(requestId, address(mockToken));

        assertEq(totalFee, 1100, "Total fee should be 1100 (1000 + 100)");

        // Create copy agent request via router
        // generate copy agent request ID
        bytes32 copyID = keccak256(abi.encodePacked(uint256(block.timestamp), address(this), requestId, block.chainid));

        // transfer some mock tokens to relayer
        address relayer = address(0xBEEF);
        mockToken.mint(relayer, totalFee);
        vm.prank(relayer);

        // grant allowance to router address
        mockToken.approve(address(iRouter), totalFee);

        // Expect the CopyAgentRequest event (from Agent, which emits the same event)
        vm.expectEmit(true, true, true, true);
        emit Agent.CopyAgentRequest(copyID, requestId, relayer, totalFee);

        assertEq(mockToken.balanceOf(relayer), totalFee, "Relayer should have enough tokens");
        assertEq(0x2e234DAe75C793f67A35089C9d99245E1C58470b, address(iRouter), "Relayer address should be correct");

        vm.prank(relayer);
        //relayer create copy request
        iRouter.createCopyAgentRequest(copyID, requestId, address(mockToken));

        // check relayer balance
        assertEq(mockToken.balanceOf(relayer), 0, "Relayer should not be charged");
    }

    function testCreateAgentWithTokenViaRouter() public {
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "app.crestal.network";

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2966);
        // Create agent with token via router
        bytes32 requestId =
            iRouter.createAgentWithToken(projectId, base64Proposal, workerAddress, serverURL, address(mockToken));

        // Check the request ID is not empty
        assertTrue(requestId != bytes32(0));

        // Check the agent request is created in BlueprintV7
        bytes32 latestProjId = iRouter.getLatestUserProjectID(address(this));
        assertEq(projectId, latestProjId);
    }

    function testUserTopUpViaRouter() public {
        // Mint some mock tokens to the user
        uint256 topUpAmount = 100 * 10 ** 18;
        mockToken.mint(address(this), topUpAmount);

        // approve blueprint to spend user's tokens
        mockToken.approve(address(iRouter), topUpAmount);

        // Expect the UserTopUp event
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUp(address(this), router.feeCollectionWalletAddress(), address(mockToken), topUpAmount);

        // Call userTopUp via router
        iRouter.userTopUp(address(mockToken), topUpAmount);

        // Check the user's balance in BlueprintV7
        uint256 userBalance = router.userTopUpMp(address(this), address(mockToken));
        assertEq(userBalance, topUpAmount, "User top-up amount is incorrect");

        // topup eth test
        uint256 ethTopUpAmount = 1 ether;
        // Expect the UserTopUp event for ETH
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUp(address(this), router.feeCollectionWalletAddress(), address(0), ethTopUpAmount);
        // Call userTopUp via router with ETH
        iRouter.userTopUp{value: ethTopUpAmount}(address(0), ethTopUpAmount);
        // Check the user's balance in BlueprintV7 for ETH
        uint256 userEthBalance = router.userTopUpMp(address(this), address(0));
        assertEq(userEthBalance, ethTopUpAmount, "User ETH top-up amount is incorrect");
    }

    function testUserTopUpOtherViaRouter() public {
        // Mint some mock tokens to the user
        uint256 topUpAmount = 100 * 10 ** 18;
        mockToken.mint(address(this), topUpAmount);

        // approve blueprint to spend user's tokens
        mockToken.approve(address(iRouter), topUpAmount);

        // Expect the UserTopUp event
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUpOther(
            address(this), workerAddress, router.feeCollectionWalletAddress(), address(mockToken), topUpAmount
        );
        // Call userTopUp via router
        iRouter.userTopUpOther(workerAddress, address(mockToken), topUpAmount);

        // Check the user's balance in BlueprintV7
        uint256 userBalance = router.userTopUpMp(workerAddress, address(mockToken));
        assertEq(userBalance, topUpAmount, "User top-up amount is incorrect");

        // topup eth test
        uint256 ethTopUpAmount = 1 ether;
        // Expect the UserTopUp event for ETH
        vm.expectEmit(true, true, true, true);
        emit Agent.UserTopUpOther(
            address(this), workerAddress, router.feeCollectionWalletAddress(), address(0), ethTopUpAmount
        );
        // Call userTopUp via router with ETH
        iRouter.userTopUpOther{value: ethTopUpAmount}(workerAddress, address(0), ethTopUpAmount);
        // Check the user's balance in BlueprintV7 for ETH
        uint256 userEthBalance = router.userTopUpMp(workerAddress, address(0));
        assertEq(userEthBalance, ethTopUpAmount, "User ETH top-up amount is incorrect");
    }

    function test_updateWorkerDeploymentConfigViaRouter() public {
        // create agent with token
        bytes32 requestId = iRouter.createAgentWithToken(projectId, "base64", workerAddress, "url", address(mockToken));
        // Expect the DeploymentConfigUpdate event
        string memory newCfg = "updated";
        vm.expectEmit(true, true, true, false);
        emit NewBlueprintCore.DeploymentConfigUpdate(projectId, requestId, workerAddress, bytes32(0), newCfg);
        iRouter.updateWorkerDeploymentConfig(address(mockToken), projectId, requestId, newCfg);
    }

    function test_updateWorkerDeploymentConfigWithSigViaRouter() public {
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // prepare gasless createAgent
        bytes32 cd = iRouter.getCreateAgentWithTokenDigest(projectId, base64, url, workerAddress, address(mockToken));
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(signerPrivateKey, cd);
        bytes memory sig0 = abi.encodePacked(r0, s0, v0);
        vm.prank(relayer);
        bytes32 requestId =
            iRouter.createAgentWithTokenWithSig(projectId, base64, workerAddress, url, address(mockToken), sig0);

        // prepare gasless update
        string memory newCfg = "cfgSig";
        uint256 nonceBefore = iRouter.getUserNonce(owner);
        bytes32 ud = iRouter.getUpdateWorkerConfigDigest(address(mockToken), projectId, requestId, newCfg, nonceBefore);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(signerPrivateKey, ud);
        bytes memory sig1 = abi.encodePacked(r1, s1, v1);

        vm.expectEmit(true, true, true, false);
        emit NewBlueprintCore.DeploymentConfigUpdate(projectId, requestId, owner, bytes32(0), newCfg);
        vm.prank(relayer);
        iRouter.updateWorkerDeploymentConfigWithSig(address(mockToken), projectId, requestId, newCfg, sig1);

        assertEq(iRouter.getUserNonce(owner), nonceBefore + 1);
    }

    function test_createAgentWithTokenWithSigViaRouter() public {
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // prepare gasless createAgent digest & sig
        bytes32 cd = iRouter.getCreateAgentWithTokenDigest(projectId, base64, url, workerAddress, address(mockToken));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, cd);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(relayer);
        bytes32 requestId =
            iRouter.createAgentWithTokenWithSig(projectId, base64, workerAddress, url, address(mockToken), sig);

        assertTrue(requestId != bytes32(0), "requestId must be non-zero");
        // check that blueprint recorded the new project for the owner
        bytes32 latest = iRouter.getLatestUserProjectID(owner);
        assertEq(latest, projectId, "projectId not recorded");
    }

    function test_setCopyAgentFeeWithSigViaRouter() public {
        address owner = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // create agent by meta-tx so deploymentOwner == owner
        bytes32 cd = iRouter.getCreateAgentWithTokenDigest(projectId, base64, url, workerAddress, address(mockToken));
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(signerPrivateKey, cd);
        bytes memory sig0 = abi.encodePacked(r0, s0, v0);
        vm.prank(relayer);
        bytes32 requestId =
            iRouter.createAgentWithTokenWithSig(projectId, base64, workerAddress, url, address(mockToken), sig0);

        uint256 fee = 1000;
        uint256 nonceBefore = iRouter.getUserNonce(owner);

        // prepare meta-tx for setCopyAgentFee
        bytes32 fd = iRouter.getSetCopyAgentFeeDigest(requestId, address(mockToken), fee, nonceBefore);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(signerPrivateKey, fd);
        bytes memory sig1 = abi.encodePacked(r1, s1, v1);

        vm.expectEmit(true, true, true, true);
        emit Agent.SetCopyAgentFee(requestId, owner, address(mockToken), fee);

        vm.prank(relayer);
        iRouter.setCopyAgentFeeWithSig(requestId, address(mockToken), fee, sig1);

        // state change
        uint256 stored = router.copyAgentFeeMp(requestId, address(mockToken));
        assertEq(stored, fee, "fee not stored");
        assertEq(iRouter.getUserNonce(owner), nonceBefore + 1, "nonce not incremented");
    }

    function test_createCopyAgentRequestWithSigViaRouter() public {
        address user = vm.addr(signerPrivateKey);
        address relayer = address(0xBEEF);
        string memory base64 = "base64";
        string memory url = "url";

        // address this create agent and then user create a copy request
        bytes32 requestId = iRouter.createAgentWithToken(projectId, base64, workerAddress, url, address(mockToken));

        // set copy-fee normally (owner can call)
        uint256 copyFee = 100; // 10 percent: 100 / 1000 (factor)
        uint256 baseFee = 1000; // 1000 nation token

        uint256 totalFee = baseFee + (copyFee * baseFee) / router.factor(); // calculate total fee based on the factor
        // set copy agent fee
        iRouter.setCopyAgentFee(requestId, address(mockToken), copyFee);

        // prepare create-copy digest & sig
        bytes32 copyID = keccak256(abi.encodePacked(block.timestamp, relayer, requestId, base64, block.chainid));
        bytes32 crd = iRouter.getCreateCopyAgentRequestDigest(copyID, requestId, address(mockToken));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signerPrivateKey, crd);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);

        // fund & approve user
        mockToken.mint(user, totalFee);
        vm.prank(user);
        mockToken.approve(address(iRouter), totalFee);

        // user balance before
        assertEq(mockToken.balanceOf(user), totalFee, "owner should have enough tokens");

        vm.expectEmit(true, true, false, false);
        emit Agent.CopyAgentRequest(copyID, requestId, user, totalFee);

        // user create copy agent request via relayer
        vm.prank(relayer);
        iRouter.createCopyAgentRequestWithSig(copyID, requestId, address(mockToken), sig2);

        // relayer balance unchanged
        assertEq(mockToken.balanceOf(relayer), 0, "relayer should not be charged");
        // user balance should be reduced by copyFee
        assertEq(mockToken.balanceOf(user), 0, "owner should be charged");
    }

    function test_getEIP712ContractAddress_via_router() public view {
        address fromBlueprint = iRouter.getEIP712ContractAddress();
        address viaRouter = iRouter.getEIP712ContractAddress();
        assertEq(viaRouter, fromBlueprint);
    }

    function test_getPaymentOpCost_via_router() public {
        // set custom costs
        iRouter.setCreateAgentTokenCost(address(mockToken), 42);
        iRouter.setUpdateCreateAgentTokenCost(address(mockToken), 84);

        uint256 c1 = router.paymentOpCostMp(address(mockToken), router.CREATE_AGENT_OP());
        uint256 c2 = router.paymentOpCostMp(address(mockToken), router.UPDATE_AGENT_OP());

        assertEq(c1, 42);
        assertEq(c2, 84);
    }

    function test_getBlueprintVersion_via_router() public view {
        string memory v0 = router.VERSION();
        string memory v1 = iRouter.VERSION();
        assertEq(v1, v0);
    }

    function test_getPaymentAddresses_via_router() public view {
        // setUp already added mockToken and address(0)
        address[] memory pays = iRouter.getPaymentAddresses();
        assertEq(pays.length, 2);
        assertEq(pays[0], address(mockToken));
        assertEq(pays[1], address(0));
    }

    function test_getWorkerAddresses_and_publicKey_via_router() public {
        // initially empty
        address[] memory w = iRouter.getWorkerAddresses();
        assertEq(w.length, 0);

        // set trusted worker address
        iRouter.updateWorker(workerAddress, true);

        vm.prank(workerAddress);
        // register a worker public key
        bytes memory pubKey = "public key";
        iRouter.setWorkerPublicKey(pubKey);

        // public key for nonexistent worker
        bytes memory key = iRouter.getWorkerPublicKey(workerAddress);
        assertEq(keccak256(key), keccak256(bytes(pubKey)), "Public key mismatch");
    }

    function test_getLatestDeploymentRequestID_via_router() public {
        // create deployment to populate latestDeploymentRequestID
        bytes32 req = iRouter.createAgentWithToken(projectId, "foo", workerAddress, "url", address(mockToken));
        bytes32 got = iRouter.getLatestDeploymentRequestID(address(this));
        assertEq(got, req);
    }

    function test_setWorkerPublicKey_via_router() public {
        // enable the worker in blueprint
        iRouter.updateWorker(workerAddress, true);

        bytes memory pubKey = "router-key";
        vm.prank(workerAddress);
        iRouter.setWorkerPublicKey(pubKey);

        // verify stored public key and address list
        bytes memory got = iRouter.getWorkerPublicKey(workerAddress);
        assertEq(keccak256(got), keccak256(pubKey), "public key mismatch");

        address[] memory addrs = iRouter.getWorkerAddresses();
        assertEq(addrs[addrs.length - 1], workerAddress, "worker address not registered");
    }

    function test_submitDeploymentRequest_via_router() public {
        // create a public deployment request (workerAddress = address(0))
        bytes32 reqId = iRouter.createAgentWithToken(projectId, "proposal", address(0), "url", address(mockToken));

        // enable the worker
        iRouter.updateWorker(workerAddress, true);

        // expect AcceptDeployment event from blueprint
        vm.expectEmit(true, true, true, false);
        emit NewBlueprintCore.AcceptDeployment(projectId, reqId, workerAddress);

        vm.prank(workerAddress);
        bool accepted = iRouter.submitDeploymentRequest(projectId, reqId);
        assertTrue(accepted, "deployment not accepted");

        // verify status and assigned worker
        (Storage.Status st, address w) = iRouter.getDeploymentStatus(reqId);
        assertEq(uint256(st), uint256(Storage.Status.Pickup), "wrong status");
        assertEq(w, workerAddress, "wrong worker assigned");
    }

    function test_submitProofOfDeployment_via_router() public {
        // create public request and claim it
        bytes32 reqId = iRouter.createAgentWithToken(projectId, "proposal", address(0), "url", address(mockToken));
        iRouter.updateWorker(workerAddress, true);
        vm.prank(workerAddress);
        iRouter.submitDeploymentRequest(projectId, reqId);

        // expect GeneratedProofOfDeployment event
        string memory proof = "proof-data";
        vm.expectEmit(true, true, false, false);
        emit NewBlueprintCore.GeneratedProofOfDeployment(projectId, reqId, proof);

        vm.prank(workerAddress);
        iRouter.submitProofOfDeployment(projectId, reqId, proof);

        // verify stored proof and status
        string memory got = iRouter.getDeploymentProof(reqId);
        assertEq(got, proof, "proof mismatch");

        (Storage.Status st,) = iRouter.getDeploymentStatus(reqId);
        assertEq(uint256(st), uint256(Storage.Status.GeneratedProof), "status not updated");
    }
}
