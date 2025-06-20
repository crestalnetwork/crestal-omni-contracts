// src/Agent.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./Blueprint.sol";

contract Worker is ERC2771Context {
    address public blueprintStorageProxy;
    address public trustRouter;
    string public VERSION;

    constructor(address _blueprintStorageProxy, address _trustedForwarder, string memory _version)
        ERC2771Context(_trustedForwarder)
    {
        trustRouter = _trustedForwarder;
        blueprintStorageProxy = _blueprintStorageProxy;
        VERSION = _version;
    }

    //todo: move more logic from blueprintCore into this contract
    function setWorkerPublicKey(bytes calldata publicKey) public {
        Blueprint(blueprintStorageProxy).setWorkerPublicKey(_msgSender(), publicKey);
    }

    function submitDeploymentRequest(bytes32 projectId, bytes32 requestID) public returns (bool isAccepted) {
        isAccepted = BlueprintCore(blueprintStorageProxy).submitDeploymentRequest(_msgSender(), projectId, requestID);
    }

    function submitProofOfDeployment(bytes32 projectId, bytes32 requestID, string memory proofBase64) public {
        BlueprintCore(blueprintStorageProxy).submitProofOfDeployment(_msgSender(), projectId, requestID, proofBase64);
    }
}
