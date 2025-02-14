pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV4} from "../src/BlueprintV4.sol";
import {Blueprint} from "../src/Blueprint.sol";
import {stdError} from "forge-std/StdError.sol";
import {MockERC721} from "./MockERC721.sol";

contract BlueprintTest is Test {
    BlueprintV4 public blueprint;
    MockERC721 public mockNFT;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;

    function setUp() public {
        blueprint = new BlueprintV4();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        mockNFT = new MockERC721();
        blueprint.setNFTContractAddress(address(mockNFT));
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
    }

    function test_VERSION() public view {
        string memory ver = blueprint.VERSION();
        assertEq(ver, "4.0.0");
    }

    function test_createAgentWithNFT() public {
        uint256 validTokenId = 1;

        // Mint an NFT to the test contract
        mockNFT.mint(address(this), validTokenId);

        // Verify ownership of the NFT
        bool isOwner = blueprint.checkNFTOwnership(address(mockNFT), validTokenId, address(this));
        assertTrue(isOwner, "Test contract does not own the NFT");

        // Expect the createAgent event
        vm.expectEmit(true, false, true, true);
        emit Blueprint.CreateAgent(projectId, "fake", address(this), validTokenId, 0);

        blueprint.createAgentWithNFT(projectId, "base64Proposal", workerAddress, "url", validTokenId);

        // Try to use the same token ID again, should revert
        vm.expectRevert("NFT token id already used");
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2981);
        blueprint.createAgentWithNFT(projectId, "base64Proposal", workerAddress, "url", validTokenId);

        validTokenId = 3;
        mockNFT.mint(workerAddress, validTokenId);

        // wrong owner should revert
        vm.expectRevert("NFT token not owned by user");
        blueprint.createAgentWithNFT(projectId, "base64Proposal", workerAddress, "url", validTokenId);
    }

    function test_createAgentWithWhitelistUsers() public {
        uint256 validTokenId = 1;

        // Mint an NFT to the test contract
        mockNFT.mint(address(this), validTokenId);

        // before whitelist, should give not whitelist error
        vm.expectRevert("user is not in whitelist");
        blueprint.createAgentWithWhitelistUsers(projectId, "base64Proposal", workerAddress, "url", validTokenId);

        // Add the test contract to the whitelist
        address[] memory whitelistAddresses = new address[](1);
        whitelistAddresses[0] = address(this);
        blueprint.setWhitelistAddress(whitelistAddresses);

        // Create agent with NFT
        blueprint.createAgentWithWhitelistUsers(projectId, "base64Proposal", workerAddress, "url", validTokenId);

        // Try to use the same address again, should revert
        vm.expectRevert("user already created agent");
        blueprint.createAgentWithWhitelistUsers(projectId, "base64Proposal", workerAddress, "url", validTokenId);
    }

    function test_createAgentWithWhitelistUsersWithSig() public {
        uint256 validTokenId = 1;
        // Define the configuration parameters
        string memory base64Proposal = "test base64 proposal";
        string memory serverURL = "http://example.com";

        // Generate the signature
        (bytes memory signature, address signerAddress) = generateSignature(projectId, base64Proposal, serverURL);

        // Mint an NFT to the test contract
        mockNFT.mint(signerAddress, validTokenId);

        // Add the test contract to the whitelist
        address[] memory whitelistAddresses = new address[](1);
        whitelistAddresses[0] = signerAddress;
        blueprint.setWhitelistAddress(whitelistAddresses);

        // Expect the createAgent event
        vm.expectEmit(true, false, true, true);
        emit Blueprint.CreateAgent(projectId, "fake", signerAddress, validTokenId, 0);

        // Create agent with createAgentWithWhitelistUsersWithSig
        blueprint.createAgentWithWhitelistUsersWithSig(
            projectId, base64Proposal, workerAddress, serverURL, validTokenId, signature
        );

        // check whitelist address status
        assertTrue(blueprint.WhitelistUsers(signerAddress) == Blueprint.Status.Pickup);
    }

    function generateSignature(bytes32 _projectId, string memory _base64Proposal, string memory _serverURL)
        internal
        returns (bytes memory, address)
    {
        bytes32 digest = blueprint.getRequestDeploymentDigest(_projectId, _base64Proposal, _serverURL);
        uint256 signerPrivateKey = 0xA11CE;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return (abi.encodePacked(r, s, v), vm.addr(0xA11CE));
    }
}
