// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Storage} from "./Storage.sol";

interface IRouterV1 {
    // ============ AGENT FUNCTIONS ============

    // Copy Agent Fee Management
    function setCopyAgentFee(bytes32 agentRequestID, address tokenAddress, uint256 fee) external;
    function setCopyAgentFeeWithSig(bytes32 agentRequestID, address tokenAddress, uint256 fee, bytes memory signature)
        external;
    function getCreateCopyAgentFee(bytes32 originalAgentRequestID, address tokenAddress)
        external
        view
        returns (uint256);

    // Copy Agent Request Creation
    function createCopyAgentRequest(bytes32 copyID, bytes32 originalAgentRequestID, address tokenAddress)
        external
        payable;
    function createCopyAgentRequestWithSig(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        bytes memory signature
    ) external payable;

    // Top Up Functions
    function userTopUp(address tokenAddress, uint256 amount) external payable;
    function userTopUpOther(address userAddress, address tokenAddress, uint256 amount) external payable;

    // ============ BLUEPRINT FUNCTIONS ============

    // NFT and Whitelist Management
    function setNFTContractAddress(address _nftContractAddress) external;
    function setWhitelistAddresses(address[] calldata whitelistAddress) external;
    function removeWhitelistAddresses(address[] calldata removedAddress) external;

    // Payment Address Management
    function addPaymentAddress(address paymentAddress) external;
    function removePaymentAddress(address paymentAddress) external;
    function setCreateAgentTokenCost(address paymentAddress, uint256 cost) external;
    function setUpdateCreateAgentTokenCost(address paymentAddress, uint256 cost) external;

    // Fee and Wallet Management
    function setFeeCollectionWalletAddress(address _feeCollectionWalletAddress) external;
    function setGlobalPlatformFee(uint256 baseFee, address paymentAddress) external;

    // Worker Management
    function setWorkerAdmin(address _workerAdmin) external;
    function updateWorker(address workerAddress, bool isTrusted) external;
    function resetWorkers() external;

    // Admin Contract Management
    function setAdminContract(address _adminContract) external;
    function removeAdminContract(address _adminContract) external;

    // Rewards
    function creditReward(address userAddress, uint256 amount) external;

    // ============ BLUEPRINT CORE FUNCTIONS ============

    // Project Management
    function createProjectID() external returns (bytes32 projectId);
    function createProjectIDAndDeploymentRequest(
        bytes32 projectId,
        string memory base64Proposal,
        string memory serverURL
    ) external returns (bytes32 requestID);
    function createProjectIDAndDeploymentRequestWithSig(
        bytes32 projectId,
        string memory base64Proposal,
        string memory serverURL,
        bytes memory signature
    ) external returns (bytes32 requestID);
    function createProjectIDAndPrivateDeploymentRequest(
        bytes32 projectId,
        string memory base64Proposal,
        address privateWorkerAddress,
        string memory serverURL
    ) external returns (bytes32 requestID);

    // Agent Creation
    function createAgentWithToken(
        bytes32 projectId,
        string memory base64Proposal,
        address privateWorkerAddress,
        string memory serverURL,
        address tokenAddress
    ) external payable returns (bytes32 requestID);
    function createAgentWithTokenWithSig(
        bytes32 projectId,
        string memory base64Proposal,
        address privateWorkerAddress,
        string memory serverURL,
        address tokenAddress,
        bytes memory signature
    ) external payable returns (bytes32 requestID);

    // Deployment Management
    function resetDeploymentRequest(
        bytes32 projectId,
        bytes32 requestID,
        address workerAddress,
        string memory base64Proposal,
        string memory serverURL
    ) external;
    function resetDeploymentRequestWithSig(
        bytes32 projectId,
        bytes32 requestID,
        address workerAddress,
        string memory base64Proposal,
        string memory serverURL,
        bytes memory signature
    ) external;
    function submitProofOfDeployment(bytes32 projectId, bytes32 requestID, string memory proofBase64) external;
    function submitDeploymentRequest(bytes32 projectId, bytes32 requestID) external returns (bool isAccepted);

    // Worker Configuration
    function updateWorkerDeploymentConfig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string memory updatedBase64Config
    ) external payable;
    function updateWorkerDeploymentConfigWithSig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string memory updatedBase64Config,
        bytes memory signature
    ) external payable;

    // Worker Public Key Management
    function setWorkerPublicKey(bytes calldata publicKey) external;
    function getWorkerPublicKey(address workerAddress) external view returns (bytes memory publicKey);
    function getWorkerAddresses() external view returns (address[] memory);

    // View Functions
    function getPaymentAddresses() external view returns (address[] memory);
    function getLatestDeploymentRequestID(address addr) external view returns (bytes32);
    function getLatestUserProjectID(address addr) external view returns (bytes32);
    function getProjectInfo(bytes32 projectId) external view returns (address, bytes32, bytes32[] memory);
    function getDeploymentProof(bytes32 requestID) external view returns (string memory);
    function getEIP712ContractAddress() external view returns (address);
    function getUserNonce(address userAddress) external view returns (uint256);
    function getDeploymentStatus(bytes32 requestID) external view returns (Storage.Status, address);

    // ============ ROUTER MANAGEMENT FUNCTIONS ============

    // Router Configuration
    function setAgent(address _agent) external;
    function setBlueprint(address _blueprint) external;
    function setSelectorTargets(bytes4[] calldata selectors, address target) external;

    // Router State
    function agent() external view returns (address);
    function blueprint() external view returns (address);
    function VERSION() external view returns (string memory);

    // ============ EIP712 FUNCTIONS ============

    // EIP712 Domain and Address
    function getAddress() external view returns (address);

    // Digest Generation Functions
    function getRequestProposalDigest(bytes32 projectId, string memory base64RecParam, string memory serverURL)
        external
        view
        returns (bytes32);
    function getRequestDeploymentDigest(bytes32 projectId, string memory base64RecParam, string memory serverURL)
        external
        view
        returns (bytes32);
    function getCreateAgentWithTokenDigest(
        bytes32 projectId,
        string memory base64RecParam,
        string memory serverURL,
        address privateWorkerAddress,
        address tokenAddress
    ) external view returns (bytes32);
    function getCreateAgentWithNFTDigest(
        bytes32 projectId,
        string memory base64RecParam,
        string memory serverURL,
        address privateWorkerAddress,
        uint256 tokenId
    ) external view returns (bytes32);
    function getUpdateWorkerConfigDigest(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string memory updatedBase64Config,
        uint256 nonce
    ) external view returns (bytes32);
    function getRequestResetDeploymentDigest(
        bytes32 projectId,
        bytes32 requestID,
        address workerAddress,
        string memory updatedBase64Config,
        uint256 nonce
    ) external view returns (bytes32);
    function getSetCopyAgentFeeDigest(bytes32 agentRequestID, address tokenAddress, uint256 fee, uint256 nonce)
        external
        view
        returns (bytes32);
    function getCreateCopyAgentRequestDigest(bytes32 copyID, bytes32 originalAgentRequestID, address tokenAddress)
        external
        view
        returns (bytes32);

    // Signature Verification
    function getSignerAddress(bytes32 hash, bytes memory signature) external pure returns (address);
}
