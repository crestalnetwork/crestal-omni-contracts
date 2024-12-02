// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

contract Blueprint {
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

    struct Project {
        bytes32 id;
        bytes32 requestProposalID;
        bytes32 requestDeploymentID;
        address proposedSolverAddr;
    }

    string public VERSION;
    uint256 public factor;
    uint256 public totalProposalRequest;
    uint256 public totalDeploymentRequest;
    address public dummyAddress = address(0);

    // user to retrieve request id via wallet address
    mapping(address => bytes32) public latestProposalRequestID;
    mapping(address => bytes32) public latestDeploymentRequestID;
    mapping(address => bytes32) public latestProjectID;

    mapping(address => uint256) public solverReputation;
    mapping(address => uint256) public workerReputation;
    // deployment status
    mapping(bytes32 => DeploymentStatus) public requestDeploymentStatus;
    // proof of deployment
    mapping(bytes32 => string) private deploymentProof;
    // private worker and solver
    mapping(bytes32 => address) private requestSolver;
    mapping(bytes32 => address) private requestWorker;

    // project map
    mapping(bytes32 => Project) private projects;

    // compatible with old contract, not change stores
    mapping(bytes32 => address) private projectIDs;

    event CreateProjectID(bytes32 indexed projectID, address walletAddress);
    event RequestProposal(
        bytes32 indexed projectID,
        address walletAddress,
        bytes32 indexed requestID,
        string base64RecParam,
        string serverURL
    );
    event RequestPrivateProposal(
        bytes32 indexed projectID,
        address walletAddress,
        address privateSolverAddress,
        bytes32 indexed requestID,
        string base64RecParam,
        string serverURL
    );
    event RequestDeployment(
        bytes32 indexed projectID,
        address walletAddress,
        address solverAddress,
        bytes32 indexed requestID,
        string base64Proposal,
        string serverURL
    );
    event RequestPrivateDeployment(
        bytes32 indexed projectID,
        address walletAddress,
        address privateWorkerAddress,
        address solverAddress,
        bytes32 indexed requestID,
        string base64Proposal,
        string serverURL
    );
    event AcceptDeployment(bytes32 indexed projectID, bytes32 indexed requestID, address indexed workerAddress);
    event GeneratedProofOfDeployment(
        bytes32 indexed projectID, bytes32 indexed requestID, string base64DeploymentProof
    );

    // get solver reputation
    function getReputation(address addr) public view returns (uint256) {
        return solverReputation[addr];
    }

    // set solver reputation
    function setReputation(address addr) private returns (uint256 reputation) {
        // get the solver reputation
        // uint256 reputation;
        reputation = solverReputation[addr];

        if (reputation < 6 * factor) {
            reputation += factor;
        } else {
            if (totalProposalRequest > 1000) {
                reputation += (reputation - 6 * factor) / totalProposalRequest;
            } else {
                reputation += (reputation - 6 * factor) / 1000;
            }
        }

        solverReputation[addr] = reputation;
    }

    function setProjectId(bytes32 projectId) internal {
        // check project id
        require(projects[projectId].id == 0, "projectId already exist");

        Project memory project;
        project.id = projectId;
        // set project info into mapping
        projects[projectId] = project;

        // set latest project
        latestProjectID[msg.sender] = projectId;

        emit CreateProjectID(projectId, msg.sender);
    }

    function createProjectID() public returns (bytes32 projectId) {
        // generate unique project id
        projectId = keccak256(abi.encodePacked(block.timestamp, msg.sender, block.chainid));

        setProjectId(projectId);
    }

    function upgradeProject(bytes32 projectId) public {
        // check project id
        require(projects[projectId].id != 0 || projectIDs[projectId] != address(0), "projectId does not exist");
        // reset project info
        projects[projectId].requestProposalID = 0;

        projects[projectId].requestDeploymentID = 0;

        projects[projectId].proposedSolverAddr = dummyAddress;
    }
    // issue RequestProposal
    // `base64RecParam` should be an encoded base64 ChainRequestParam json string
    // https://github.com/crestalnetwork/crestal-dashboard-backend/blob/testnet-dev/listen/type.go#L9
    // example: {"type":"DA","latency":5,"max_throughput":20,"finality_time":10,"block_time":5,"created_at":"0001-01-01T00:00:00Z"}
    // associated base64 string: eyJ0eXBlIjoiREEiLCJsYXRlbmN5Ijo1LCJtYXhfdGhyb3VnaHB1dCI6MjAsImZpbmFsaXR5X3RpbWUiOjEwLCJibG9ja190aW1lIjo1LCJjcmVhdGVkX2F0IjoiMDAwMS0wMS0wMVQwMDowMDowMFoifQ

    function createProposalRequest(bytes32 projectId, string memory base64RecParam, string memory serverURL)
        public
        returns (bytes32 requestID)
    {
        requestID = proposalRequest(projectId, dummyAddress, base64RecParam, serverURL);

        emit RequestProposal(projectId, msg.sender, requestID, base64RecParam, serverURL);
    }

    function createPrivateProposalRequest(
        bytes32 projectId,
        address privateSolverAddress,
        string memory base64RecParam,
        string memory serverURL
    ) public returns (bytes32 requestID) {
        requestID = proposalRequest(projectId, privateSolverAddress, base64RecParam, serverURL);

        emit RequestPrivateProposal(projectId, msg.sender, privateSolverAddress, requestID, base64RecParam, serverURL);
    }

    function createProjectIDAndProposalRequest(bytes32 projectId, string memory base64RecParam, string memory serverURL)
        public
    {
        // set project id
        setProjectId(projectId);
        // create proposal request
        createProposalRequest(projectId, base64RecParam, serverURL);
    }

    function proposalRequest(
        bytes32 projectId,
        address solverAddress,
        string memory base64RecParam,
        string memory serverURL
    ) internal returns (bytes32 requestID) {
        // check project id

        require(projects[projectId].id != 0 || projectIDs[projectId] != address(0), "projectId does not exist");

        require(bytes(serverURL).length > 0, "serverURL is empty");
        require(bytes(base64RecParam).length > 0, "base64RecParam is empty");

        // generate unique hash
        requestID = keccak256(abi.encodePacked(block.timestamp, msg.sender, base64RecParam, block.chainid));

        // check request id is created or not
        require(projects[projectId].requestProposalID == 0, "proposasl request id already exist");

        // FIXME: This prevents a msg.sender to create multiple requests at the same time?
        // For different projects, a solver is allowed to create one (latest proposal) for each.
        latestProposalRequestID[msg.sender] = requestID;

        projects[projectId].requestProposalID = requestID;

        totalProposalRequest++;

        // set request id associated private solver
        if (solverAddress != address(0)) {
            // private proposal request
            requestSolver[requestID] = solverAddress;
        }

        return requestID;
    }

    // issue DeploymentRequest
    // `base64Proposal` should be encoded base64 ChainRequestParam json string
    // that was sent in `createProposalRequest` call
    // TODO: Why not just pass in requestID here?
    function createDeploymentRequest(
        bytes32 projectId,
        address solverAddress,
        string memory base64Proposal,
        string memory serverURL
    ) public returns (bytes32 requestID) {
        require(solverAddress != address(0), "solverAddress is not valid");

        requestID = DeploymentRequest(projectId, solverAddress, dummyAddress, base64Proposal, serverURL);

        emit RequestDeployment(projectId, msg.sender, solverAddress, requestID, base64Proposal, serverURL);
    }

    function createPrivateDeploymentRequest(
        bytes32 projectId,
        address solverAddress,
        address privateWorkerAddress,
        string memory base64Proposal,
        string memory serverURL
    ) public returns (bytes32 requestID) {
        require(solverAddress != address(0), "solverAddress is not valid");

        requestID = DeploymentRequest(projectId, solverAddress, privateWorkerAddress, base64Proposal, serverURL);

        emit RequestPrivateDeployment(
            projectId, msg.sender, privateWorkerAddress, solverAddress, requestID, base64Proposal, serverURL
        );

        // emit accept deployment event since this deployment request is accepted by blueprint
        emit AcceptDeployment(projectId, requestID, privateWorkerAddress);
    }

    function DeploymentRequest(
        bytes32 projectId,
        address solverAddress,
        address workerAddress,
        string memory base64Proposal,
        string memory serverURL
    ) internal returns (bytes32 requestID) {
        require(projects[projectId].id != 0 || projectIDs[projectId] != address(0), "projectId does not exist");

        require(bytes(serverURL).length > 0, "serverURL is empty");
        require(bytes(base64Proposal).length > 0, "base64Proposal is empty");

        // generate unique message hash
        requestID = keccak256(abi.encodePacked(block.timestamp, msg.sender, base64Proposal, block.chainid));

        // check request id is created or not
        require(projects[projectId].requestDeploymentID == 0, "deployment request id already exist");

        latestDeploymentRequestID[msg.sender] = requestID;

        totalDeploymentRequest++;

        // set solver reputation
        setReputation(solverAddress);

        DeploymentStatus memory deploymentStatus;
        if (workerAddress == address(0)) {
            // init deployment status, not picked by any worker
            deploymentStatus.status = Status.Issued;

            requestDeploymentStatus[requestID] = deploymentStatus;
        } else {
            // private deployment request
            // pick up deployment status since this is private deployment request, which can be picked only by refered worker
            deploymentStatus.status = Status.Pickup;
            deploymentStatus.deployWorkerAddr = workerAddress;

            requestDeploymentStatus[requestID] = deploymentStatus;
        }

        // update project info
        projects[projectId].requestDeploymentID = requestID;

        projects[projectId].proposedSolverAddr = solverAddress;

        return requestID;
    }

    function createProjectIDAndDeploymentRequest(
        bytes32 projectId,
        string memory base64Proposal,
        string memory serverURL
    ) public returns (bytes32 requestID) {
        // set project id
        setProjectId(projectId);

        // create deployment request without solver recommendation
        requestID = DeploymentRequest(projectId, dummyAddress, dummyAddress, base64Proposal, serverURL);

        emit RequestDeployment(projectId, msg.sender, dummyAddress, requestID, base64Proposal, serverURL);
    }

    function submitProofOfDeployment(bytes32 projectId, bytes32 requestID, string memory proofBase64) public {
        require(projects[projectId].id != 0 || projectIDs[projectId] != address(0), "projectId does not exist");

        require(requestID.length > 0, "requestID is empty");
        require(requestDeploymentStatus[requestID].status != Status.Init, "request ID not exit");
        require(requestDeploymentStatus[requestID].deployWorkerAddr == msg.sender, "wrong worker address");

        require(requestDeploymentStatus[requestID].status != Status.GeneratedProof, "already submit proof");

        // set deployment status into generatedProof
        requestDeploymentStatus[requestID].status = Status.GeneratedProof;

        // save deployment proof to mapping
        deploymentProof[requestID] = proofBase64;

        emit GeneratedProofOfDeployment(projectId, requestID, proofBase64);
    }

    function submitDeploymentRequest(bytes32 projectId, bytes32 requestID) public returns (bool isAccepted) {
        require(projects[projectId].id != 0 || projectIDs[projectId] != address(0), "projectId does not exist");

        require(requestID.length > 0, "requestID is empty");
        require(requestDeploymentStatus[requestID].status != Status.Init, "requestID does not exist");
        require(
            requestDeploymentStatus[requestID].status != Status.Pickup,
            "requestID already picked by another worker, try a different requestID"
        );

        require(requestDeploymentStatus[requestID].status != Status.GeneratedProof, "requestID already submit proof");

        // currently, do first come, first server, will do a better way in the future
        requestDeploymentStatus[requestID].status = Status.Pickup;
        requestDeploymentStatus[requestID].deployWorkerAddr = msg.sender;

        // set project deployed worker address
        isAccepted = true;

        emit AcceptDeployment(projectId, requestID, requestDeploymentStatus[requestID].deployWorkerAddr);
    }

    // get latest deployment status
    function getDeploymentStatus(bytes32 requestID) public view returns (Status, address) {
        return (requestDeploymentStatus[requestID].status, requestDeploymentStatus[requestID].deployWorkerAddr);
    }

    // get latest proposal request id
    function getLatestProposalRequestID(address addr) public view returns (bytes32) {
        return latestProposalRequestID[addr];
    }

    // get latest deployment request id
    function getLatestDeploymentRequestID(address addr) public view returns (bytes32) {
        return latestDeploymentRequestID[addr];
    }

    // get latest project id of user
    function getLatestUserProjectID(address addr) public view returns (bytes32) {
        return latestProjectID[addr];
    }

    // get project info
    function getProjectInfo(bytes32 projectId) public view returns (address, bytes32, bytes32) {
        require(projects[projectId].id != 0, "projectId does not exist");

        return (
            projects[projectId].proposedSolverAddr,
            projects[projectId].requestProposalID,
            projects[projectId].requestDeploymentID
        );
    }
}
