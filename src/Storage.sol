// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

abstract contract Storage {
    // copy from blueprintCore to keep storage layout compatible
    enum Status {
        Init,
        Issued,
        Pickup,
        Deploying,
        Deployed,
        GeneratedProof
    }

    struct DeploymentStatus {
        Status status;
        address deployWorkerAddr;
    }

    // slither-disable-next-line naming-convention
    string public VERSION;
    // This is considered initialized due to BlueprintV1 deployment, however
    // for future upgrades, it can be seen as "uninitialized" but we should
    // not override it again in upgrades unless absolutely necessary
    // slither-disable-next-line uninitialized-state,constable-states
    uint256 public factor;
    // This is no longer used, but for upgradeable compatibility, it stays
    // slither-disable-next-line constable-states
    uint256 public totalProposalRequest;
    uint256 public totalDeploymentRequest;

    // This is no longer used, but for upgradeable compatibility, it stays
    // slither-disable-next-line uninitialized-state
    mapping(address => bytes32) public latestProposalRequestID;
    mapping(address => bytes32) public latestDeploymentRequestID;
    mapping(address => bytes32) public latestProjectID;

    mapping(address => uint256) public solverReputation;
    mapping(address => uint256) public workerReputation;
    mapping(bytes32 => DeploymentStatus) public requestDeploymentStatus;

    mapping(bytes32 => string) private deploymentProof;
    mapping(bytes32 => address) private requestSolver;
    mapping(bytes32 => address) private requestWorker;
    // projectIDs is not used anymore after 2.0
    mapping(bytes32 => address) private projectIDs;

    // keep old variable in order so that it can be compatible with old contract

    // new variable and struct
    struct Project {
        bytes32 id;
        bytes32 requestProposalID;
        bytes32 requestDeploymentID;
        address proposedSolverAddr;
    }

    address public constant dummyAddress = address(0);

    // project map
    mapping(bytes32 => Project) private projects;

    mapping(bytes32 => bytes32[]) public deploymentIdList;

    // List of worker addresses
    address[] private workerAddresses;
    // worker public key
    mapping(address => bytes) private workersPublicKey;

    // worker address mapping
    mapping(string => address[]) private workerAddressesMp;

    string private constant WORKER_ADDRESS_KEY = "worker_address_key";

    // NFT token id mapping, one NFT token id can only be used once
    mapping(uint256 => Status) public nftTokenIdMap;

    address public nftContractAddress;

    // whitelist user can create an agent
    mapping(address => Status) public whitelistUsers;

    // deployment owner
    mapping(bytes32 => address) private deploymentOwners;

    // payment related variables
    string public constant PAYMENT_KEY = "payment_key";

    string public constant CREATE_AGENT_OP = "create_agent";
    string public constant UPDATE_AGENT_OP = "update_agent";

    address public feeCollectionWalletAddress;

    mapping(string => address[]) public paymentAddressesMp;

    mapping(address => bool) public paymentAddressEnableMp;

    mapping(address => mapping(string => uint256)) public paymentOpCostMp;

    mapping(address => mapping(address => uint256)) public userTopUpMp;

    mapping(address => uint256) private userNonceMp;

    // worker management related variables
    address public workerAdmin;
    mapping(address => bool) public trustWorkerMp;
    // deployment request id to project id mapping
    mapping(bytes32 => bytes32) public requestIDToProjectID;

    // agent copy fee mapping
    mapping(address => bool) public adminContracts;
    mapping(address => uint256) public platformFee;
    mapping(bytes32 => mapping(address => uint256)) public copyAgentFeeMp;

    // deploymentOwners
    function _getDeploymentOwner(bytes32 req) internal view returns (address) {
        return deploymentOwners[req];
    }

    function _setDeploymentOwner(bytes32 req, address ownerAddr) internal {
        deploymentOwners[req] = ownerAddr;
    }

    // Getter & setter for userNonceMp
    function _getUserNonce(address _user) internal view returns (uint256) {
        return userNonceMp[_user];
    }

    function _setUserNonce(address _user, uint256 _nonce) internal {
        userNonceMp[_user] = _nonce;
    }

    // Getter & setter for deploymentProof
    function _getDeploymentProof(bytes32 requestID) internal view returns (string memory) {
        return deploymentProof[requestID];
    }

    function _setDeploymentProof(bytes32 requestID, string memory proof) internal {
        deploymentProof[requestID] = proof;
    }

    // Getter & setter for projects
    function _getProjectInfo(bytes32 projectId)
        internal
        view
        returns (bytes32 id, bytes32 requestProposalID, bytes32 requestDeploymentID, address proposedSolverAddr)
    {
        Project memory p = projects[projectId];
        return (p.id, p.requestProposalID, p.requestDeploymentID, p.proposedSolverAddr);
    }

    function _getProject(bytes32 projectId) internal view returns (Project storage) {
        return projects[projectId];
    }

    function _setProject(bytes32 projectId, Project memory project) internal {
        projects[projectId] = project;
    }

    function _setProjectInfo(
        bytes32 projectId,
        bytes32 id,
        bytes32 requestProposalID,
        bytes32 requestDeploymentID,
        address proposedSolverAddr
    ) internal {
        projects[projectId] = Project({
            id: id,
            requestProposalID: requestProposalID,
            requestDeploymentID: requestDeploymentID,
            proposedSolverAddr: proposedSolverAddr
        });
    }

    function _getProjectId(bytes32 projectId) internal view returns (address) {
        return projectIDs[projectId];
    }

    // Getter & setter for workerAddressesMp
    function _getWorkerAddressesMp() internal view returns (address[] memory) {
        return workerAddressesMp[WORKER_ADDRESS_KEY];
    }

    function _setWorkerAddressesMp(address[] memory addrs) internal {
        workerAddressesMp[WORKER_ADDRESS_KEY] = addrs;
    }

    function _pushWorkerAddressMp(address worker) internal {
        workerAddressesMp[WORKER_ADDRESS_KEY].push(worker);
    }

    function _deleteWorkerAddressesMp() internal {
        delete workerAddressesMp[WORKER_ADDRESS_KEY];
    }

    // Getter & setter for workersPublicKey
    function _getWorkersPublicKey(address worker) internal view returns (bytes memory) {
        return workersPublicKey[worker];
    }

    function _setWorkersPublicKey(address worker, bytes memory publicKey) internal {
        workersPublicKey[worker] = publicKey;
    }

    function _deleteWorkersPublicKey(address worker) internal {
        delete workersPublicKey[worker];
    }
}
