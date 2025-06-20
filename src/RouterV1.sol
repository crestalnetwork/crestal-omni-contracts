// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Payment} from "./Payment.sol";
import {Blueprint} from "./Blueprint.sol";
import {Agent} from "./Agent.sol";
import {Worker} from "./Worker.sol";

/// @title RouterV1 - EIP-2771 Forwarder and Router for Agent and Blueprint
/// @notice Forwards all public/external functions of Agent and Blueprint, appending the original sender for EIP-2771 meta-tx compatibility
contract RouterV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable, Payment {
    address public agent;
    address public blueprint;
    address public worker;
    string public VERSION;

    function initialize() public reinitializer(1) {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        VERSION = "1.0.0";
    }

    function setForwardContracts(address _agent, address _blueprint) external onlyOwner {
        agent = _agent;
        blueprint = _blueprint;
    }

    function setWorker(address _worker) external onlyOwner {
        worker = _worker;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // =========================
    // Agent.sol Routing
    // =========================

    function setCopyAgentFee(bytes32 agentRequestID, address tokenAddress, uint256 fee) external {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("setCopyAgentFee(bytes32,address,uint256)")), agentRequestID, tokenAddress, fee
        );
        (bool success, bytes memory returndata) = agent.call(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    function setCopyAgentFeeWithSig(bytes32 agentRequestID, address tokenAddress, uint256 fee, bytes memory signature)
        external
    {
        Agent(agent).setCopyAgentFeeWithSig(agentRequestID, tokenAddress, fee, signature);
    }

    function createCopyAgentRequest(bytes32 copyID, bytes32 originalAgentRequestID, address tokenAddress)
        external
        payable
    {
        uint256 fee = Blueprint(blueprint).copyAgentFeeMp(originalAgentRequestID, tokenAddress);
        // transfer funds to agent
        if (tokenAddress != address(0)) {
            // transfer ERC20 tokens to agent
            payWithERC20(tokenAddress, fee, msg.sender, agent);
        }

        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("createCopyAgentRequest(bytes32,bytes32,address)")),
            copyID,
            originalAgentRequestID,
            tokenAddress
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    function createCopyAgentRequestWithSig(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        bytes memory signature
    ) external payable {
        uint256 fee = Blueprint(blueprint).copyAgentFeeMp(originalAgentRequestID, tokenAddress);

        // get digest
        bytes32 digest =
            Blueprint(blueprint).getCreateCopyAgentRequestDigest(copyID, originalAgentRequestID, tokenAddress);
        // get signer address
        address signer = Blueprint(blueprint).getSignerAddress(digest, signature);

        // transfer funds to agent
        if (tokenAddress != address(0)) {
            // transfer ERC20 tokens to agent
            payWithERC20(tokenAddress, fee, signer, agent);
        }

        Agent(agent).createCopyAgentRequestWithSig{value: msg.value}(
            copyID, originalAgentRequestID, tokenAddress, signature
        );
    }

    function createAgentWithToken(
        bytes32 projectId,
        string calldata base64Proposal,
        address privateWorkerAddress,
        string calldata serverURL,
        address tokenAddress
    ) external payable returns (bytes32) {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("createAgentWithToken(bytes32,string,address,string,address)")),
            projectId,
            base64Proposal,
            privateWorkerAddress,
            serverURL,
            tokenAddress
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (bytes32));
    }

    function createAgentWithTokenWithSig(
        bytes32 projectId,
        string calldata base64Proposal,
        address privateWorkerAddress,
        string calldata serverURL,
        address tokenAddress,
        bytes calldata signature
    ) external payable returns (bytes32) {
        return Agent(agent).createAgentWithTokenWithSig{value: msg.value}(
            projectId, base64Proposal, privateWorkerAddress, serverURL, tokenAddress, signature
        );
    }

    function updateWorkerDeploymentConfig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string calldata updatedBase64Config
    ) external payable {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("updateWorkerDeploymentConfig(address,bytes32,bytes32,string)")),
            tokenAddress,
            projectId,
            requestID,
            updatedBase64Config
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    function updateWorkerDeploymentConfigWithSig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string calldata updatedBase64Config,
        bytes calldata signature
    ) external payable {
        Agent(agent).updateWorkerDeploymentConfigWithSig{value: msg.value}(
            tokenAddress, projectId, requestID, updatedBase64Config, signature
        );
    }

    // --- Payment/TopUp ---
    function userTopUp(address tokenAddress, uint256 amount) external payable {
        // transfer funds to agent
        if (tokenAddress != address(0)) {
            // transfer ERC20 tokens to agent
            payWithERC20(tokenAddress, amount, msg.sender, agent);
        }

        // then agent contract handle the top up
        bytes memory data =
            abi.encodeWithSelector(bytes4(keccak256("userTopUp(address,uint256)")), tokenAddress, amount);
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));

        require(success, _getRevertMsg(returndata));
    }

    function userTopUpOther(address userAddress, address tokenAddress, uint256 amount) external payable {
        // transfer funds to agent
        if (tokenAddress != address(0)) {
            // transfer ERC20 tokens to agent
            payWithERC20(tokenAddress, amount, msg.sender, agent);
        }

        // then agent contract handle the topup other
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("userTopUpOther(address,address,uint256)")), userAddress, tokenAddress, amount
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    // forward worker function for all public/external functions
    function setWorkerPublicKey(bytes calldata publicKey) external {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setWorkerPublicKey(bytes)")), publicKey);
        (bool success, bytes memory returndata) = worker.call(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    function submitDeploymentRequest(bytes32 projectId, bytes32 requestID) external returns (bool isAccepted) {
        bytes memory data =
            abi.encodeWithSelector(bytes4(keccak256("submitDeploymentRequest(bytes32,bytes32)")), projectId, requestID);
        (bool success, bytes memory returndata) = worker.call(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (bool));
    }

    function submitProofOfDeployment(bytes32 projectId, bytes32 requestID, string memory proofBase64) external {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("submitProofOfDeployment(bytes32,bytes32,string)")), projectId, requestID, proofBase64
        );
        (bool success, bytes memory returndata) = worker.call(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    // forward storage proxy function for all get function
    function getWorkerPublicKey(address workerAddress) external view returns (bytes memory) {
        return Blueprint(blueprint).getWorkerPublicKey(workerAddress);
    }

    function getWorkerAddresses() external view returns (address[] memory) {
        return Blueprint(blueprint).getWorkerAddresses();
    }

    function getPaymentAddresses() external view returns (address[] memory) {
        return Blueprint(blueprint).getPaymentAddresses();
    }

    function getLatestDeploymentRequestID(address addr) external view returns (bytes32) {
        return Blueprint(blueprint).getLatestDeploymentRequestID(addr);
    }

    function getLatestUserProjectID(address addr) external view returns (bytes32) {
        return Blueprint(blueprint).getLatestUserProjectID(addr);
    }

    function getProjectInfo(bytes32 projectId) external view returns (address, bytes32, bytes32[] memory) {
        return Blueprint(blueprint).getProjectInfo(projectId);
    }

    function getDeploymentProof(bytes32 requestID) external view returns (string memory) {
        return Blueprint(blueprint).getDeploymentProof(requestID);
    }

    function getEIP712ContractAddress() external view returns (address) {
        return Blueprint(blueprint).getEIP712ContractAddress();
    }

    // --- Nonce/Ownership/Status ---
    function getUserNonce(address userAddress) external view returns (uint256) {
        return Blueprint(blueprint).getUserNonce(userAddress);
    }

    function getDeploymentOwner(bytes32 agentRequestID) external view returns (address) {
        return Blueprint(blueprint).getDeploymentOwner(agentRequestID);
    }

    function getDeploymentStatus(bytes32 requestID) external view returns (Blueprint.Status, address) {
        return Blueprint(blueprint).getDeploymentStatus(requestID);
    }

    function getBlueprintVersion() external view returns (string memory) {
        return Blueprint(blueprint).VERSION();
    }

    function getPaymentOpCost(address tokenAddress, string calldata op) external view returns (uint256) {
        return Blueprint(blueprint).paymentOpCostMp(tokenAddress, op);
    }

    // Helper to bubble up revert reasons
    function _getRevertMsg(bytes memory returndata) private pure returns (string memory) {
        if (returndata.length < 68) return "RouterV1: Forwarded call failed";
        assembly {
            returndata := add(returndata, 0x04)
        }
        return abi.decode(returndata, (string));
    }
}
