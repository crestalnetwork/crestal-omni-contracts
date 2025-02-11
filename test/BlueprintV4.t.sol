pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV4} from "../src/BlueprintV4.sol";
import {Blueprint} from "../src/Blueprint.sol";
import {stdError} from "forge-std/StdError.sol";

contract BlueprintTest is Test {
    BlueprintV4 public blueprint;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;

    function setUp() public {
        blueprint = new BlueprintV4();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior
        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
    }

    function test_VERSION() public view {
        string memory ver = blueprint.VERSION();
        assertEq(ver, "9.0.0");
    }

    function test_createAgentWithNFT() public {
        //todo: mock up checkNFTOwnership so that bypass evm revert
        //        uint256 validTokenId = 1;
        //
        //        blueprint.createAgentWithNFT(projectId, "base64Proposal", workerAddress, "url", validTokenId);
        //
        ////         Try to use the same token ID again, should revert
        //        vm.expectRevert("NFT token id already used");
        //        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2981);
        //        blueprint.createAgentWithNFT(projectId, "base64Proposal", workerAddress, "url", validTokenId);
        //
    }
}
