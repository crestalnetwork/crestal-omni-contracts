// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title RouterV1 - EIP-2771 Forwarder and Router for Agent and Blueprint
/// @notice Forwards all public/external functions of Agent and Blueprint, appending the original sender for EIP-2771 meta-tx compatibility
contract RouterV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address public agent;
    address public blueprint;
    string public VERSION;

    function initialize() public reinitializer(1) {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        VERSION = "7.0.0";
    }

    function setForwardContracts(address _agent, address _blueprint) external onlyOwner {
        agent = _agent;
        blueprint = _blueprint;
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
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("setCopyAgentFeeWithSig(bytes32,address,uint256,bytes)")),
            agentRequestID,
            tokenAddress,
            fee,
            signature
        );
        (bool success, bytes memory returndata) = agent.call(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    function createCopyAgentRequest(bytes32 copyID, bytes32 originalAgentRequestID, address tokenAddress)
        external
        payable
    {
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
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("createCopyAgentRequestWithSig(bytes32,bytes32,address,bytes)")),
            copyID,
            originalAgentRequestID,
            tokenAddress,
            signature
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
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
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("createAgentWithTokenWithSig(bytes32,string,address,string,address,bytes)")),
            projectId,
            base64Proposal,
            privateWorkerAddress,
            serverURL,
            tokenAddress,
            signature
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (bytes32));
    }

    // --- Payment/TopUp ---
    function userTopUp(address tokenAddress, uint256 amount) external payable {
        bytes memory data =
            abi.encodeWithSelector(bytes4(keccak256("userTopUp(address,uint256)")), tokenAddress, amount);
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    function userTopUpOther(address userAddress, address tokenAddress, uint256 amount) external payable {
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("userTopUpOther(address,address,uint256)")), userAddress, tokenAddress, amount
        );
        (bool success, bytes memory returndata) = agent.call{value: msg.value}(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
    }

    // =========================
    // BlueprintCore.sol Routing (public/external only)
    // =========================

    //    function submitProofOfDeployment(bytes32 projectId, bytes32 requestID, string calldata proofBase64) external {
    //        bytes memory data = abi.encodeWithSelector(
    //            bytes4(keccak256("submitProofOfDeployment(bytes32,bytes32,string)")), projectId, requestID, proofBase64
    //        );
    //        (bool success, bytes memory returndata) = blueprint.call(abi.encodePacked(data, msg.sender));
    //        require(success, _getRevertMsg(returndata));
    //    }
    //
    //    function submitDeploymentRequest(bytes32 projectId, bytes32 requestID) external returns (bool) {
    //        bytes memory data =
    //            abi.encodeWithSelector(bytes4(keccak256("submitDeploymentRequest(bytes32,bytes32)")), projectId, requestID);
    //        (bool success, bytes memory returndata) = blueprint.call(abi.encodePacked(data, msg.sender));
    //        require(success, _getRevertMsg(returndata));
    //        return abi.decode(returndata, (bool));
    //    }

    // --- Worker/Public Key Management ---
    //    function setWorkerPublicKey(bytes calldata publicKey) external {
    //        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setWorkerPublicKey(bytes)")), publicKey);
    //        (bool success, bytes memory returndata) = blueprint.call(abi.encodePacked(data, msg.sender));
    //        require(success, _getRevertMsg(returndata));
    //    }

    function getWorkerAddresses() external view returns (address[] memory) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getWorkerAddresses()")));
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (address[]));
    }

    function getPaymentAddresses() external view returns (address[] memory) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getPaymentAddresses()")));
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (address[]));
    }

    function getLatestDeploymentRequestID(address addr) external view returns (bytes32) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getLatestDeploymentRequestID(address)")), addr);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (bytes32));
    }

    function getLatestUserProjectID(address addr) external view returns (bytes32) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getLatestUserProjectID(address)")), addr);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (bytes32));
    }

    function getProjectInfo(bytes32 projectId) external view returns (address, bytes32, bytes32[] memory) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getProjectInfo(bytes32)")), projectId);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (address, bytes32, bytes32[]));
    }

    function getDeploymentProof(bytes32 requestID) external view returns (string memory) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getDeploymentProof(bytes32)")), requestID);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (string));
    }

    function getEIP712ContractAddress() external view returns (address) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getEIP712ContractAddress()")));
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (address));
    }

    // --- Nonce/Ownership/Status ---
    function getUserNonce(address userAddress) external view returns (uint256) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getUserNonce(address)")), userAddress);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (uint256));
    }

    function getDeploymentOwner(bytes32 agentRequestID) external view returns (address) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getDeploymentOwner(bytes32)")), agentRequestID);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (address));
    }

    function getDeploymentStatus(bytes32 requestID) external view returns (uint8, address) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("getDeploymentStatus(bytes32)")), requestID);
        (bool success, bytes memory returndata) = blueprint.staticcall(abi.encodePacked(data, msg.sender));
        require(success, _getRevertMsg(returndata));
        return abi.decode(returndata, (uint8, address));
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
