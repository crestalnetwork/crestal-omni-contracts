// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

contract blueprint {

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


    bytes32 private messageHash;
    mapping(address => bytes32) public latestProposalRequestID;
    mapping(address => bytes32) public latestDeploymentRequestID;
    mapping (address => uint256) public solverReputation;
    mapping (address => uint256) public workerReputation;
    mapping (bytes32 => DeploymentStatus) public requestDeploymentStatus;
    mapping (bytes32 => string) private deploymentProof;
    mapping (bytes32 => address) private requestSolver;
    mapping (bytes32 => address) private requestWorker;

    uint256 public factor;
    uint256 public totalProposalRequest;
    uint256 public totalDeploymentRequest;

    event RequestProposal(address indexed walletAddress, bytes32 indexed messageHash, string base64RecParam, string serverURL);
    event RequestPrivateProposal(address indexed walletAddress, address privateSolverAddress, bytes32 messageHash, string base64RecParam, string serverURL);
    event RequestDeployment(address indexed walletAddress,address indexed solverAddress, bytes32 indexed messageHash,string base64Proposal, string serverURL);
    event RequestPrivateDeployment(address indexed walletAddress, address privateWorkerAddress, address indexed solverAddress, bytes32 messageHash, string base64Proposal, string serverURL);
    event AcceptDeployment(bytes32 indexed requestID, address indexed workerAddress);
    event GeneratedProofOfDeployment(bytes32 indexed requestID, string base64DeploymentProof);

    constructor() {
        // set the factor, used for float type calculation
        factor = 10000;
        totalProposalRequest = 0;
        totalDeploymentRequest = 0;
    }
    // get solver reputation
    function getReputation(address addr) public view returns (uint256) {
        return solverReputation[addr];
    }

    // set solver reputation
    function setReputation(address addr) private returns (uint256 reputation) {
        // get the solver reputation
        // uint256 reputation;
        reputation = solverReputation[addr];

        if (reputation <  6 * factor ) {
            reputation += factor;
        } else {
            if (totalProposalRequest > 1000) {
                reputation +=  (reputation - 6 * factor) / totalProposalRequest;
            } else {
                reputation +=  (reputation - 6 * factor) / 1000;
            }
        }

        solverReputation[addr] = reputation;

    }


    // issue RequestProposal
    //  data should be encoded base64 ChainRequestParam json string
    //  example: {"types":["DA"],"uptime":0,"latency":0,"throughput":20,"error_rate":0.1,"cost":4,"init_cost":0,"maintenance_cost":0,"extra_attribute":""}
    //   associated base64 string: eyJ0eXBlcyI6WyJEQSJdLCJ1cHRpbWUiOjAsImxhdGVuY3kiOjAsInRocm91Z2hwdXQiOjIwLCJlcnJvcl9yYXRlIjowLjEsImNvc3QiOjQsImluaXRfY29zdCI6MCwibWFpbnRlbmFuY2VfY29zdCI6MCwiZXh0cmFfYXR0cmlidXRlIjoiIn0=
//        type ChainRequestParam struct {
//            // lots of filed coped from DAInfo
//            Types            []string `json:"types"`
//            DAProposal                // Embed DAProposal
//            IndexingProposal          // Embed IndexingProposal
//            StorageProposal           // Embed StorageProposal
//            ComputeProposal           // Embed ComputeProposal
//    }

    function createProposalRequest(string memory base64RecParam, string memory serverURL) public returns (bytes32 requestID) {

        require (bytes(serverURL).length > 0, "server URL is empty");
        require (bytes(base64RecParam).length >  0, "base64RecParam is empty");

        // generate unique hash
        messageHash = keccak256(abi.encodePacked(block.timestamp,msg.sender,base64RecParam));

        requestID = messageHash;

        latestProposalRequestID[msg.sender] = requestID;

        totalProposalRequest++;

        emit RequestProposal(msg.sender,messageHash,base64RecParam,serverURL);

    }

    function createPrivateProposalRequest(address privateSolverAddress,string memory base64RecParam, string memory serverURL) public returns (bytes32 requestID) {
        require (bytes(serverURL).length > 0, "server URL is empty");
        require (bytes(base64RecParam).length >  0, "base64RecParam is empty");

        // generate unique hash
        messageHash = keccak256(abi.encodePacked(block.timestamp,msg.sender,base64RecParam));

        requestID = messageHash;

        latestProposalRequestID[msg.sender] = requestID;

        totalProposalRequest++;

        // set request id associated private solver
        requestSolver[requestID] = privateSolverAddress;

        emit RequestPrivateProposal(msg.sender,privateSolverAddress, messageHash,base64RecParam,serverURL);

    }

//   ex base64Propsal: eyJ0eXBlIjoiREEiLCJsYXRlbmN5Ijo1LCJtYXhfdGhyb3VnaHB1dCI6MjAsImZpbmFsaXR5X3RpbWUiOjEwLCJibG9ja190aW1lIjo1LCJjcmVhdGVkX2F0IjoiMDAwMS0wMS0wMVQwMDowMDowMFoifQ
//        type ChainRequestParam struct {
//    // lots of filed coped from DAInfo
//            Type             string `json:"type"`
//            DAProposal              // Embed DAProposal
//            IndexingProposal        // Embed IndexingProposal
//            StorageProposal         // Embed StorageProposal
//            ComputeProposal         // Embed ComputeProposal
//    }
    function createDeploymentRequest(address solverAddress,string memory base64Proposal, string memory serverURL) public returns (bytes32 requestID){
        require (bytes(serverURL).length > 0, "server URL is empty");
        require (bytes(base64Proposal).length >  0, "base64Proposal is empty");

        // generate unique message hash
        messageHash = keccak256(abi.encodePacked(block.timestamp,msg.sender,base64Proposal));

        requestID = messageHash;

        latestDeploymentRequestID[msg.sender] = requestID;

        totalDeploymentRequest++;


        // init deployment status, not picked by any worker
        DeploymentStatus memory deploymentStatus;
        deploymentStatus.status = Status.Issued;

        requestDeploymentStatus[requestID] = deploymentStatus;

        // set solver reputation
        setReputation(solverAddress);

        emit RequestDeployment(msg.sender,solverAddress,messageHash, base64Proposal,serverURL);

    }

    function createPrivateDeploymentRequest(address solverAddress, address privateWorkerAddress, string memory base64Proposal, string memory serverURL) public returns (bytes32 requestID) {

        require (bytes(serverURL).length > 0, "server URL is empty");
        require (bytes(base64Proposal).length > 0, "base64Proposal is empty");

        require(solverAddress != address(0),"solverAddress not validate");

        // generate unique message hash
        messageHash = keccak256(abi.encodePacked(block.timestamp,msg.sender,base64Proposal));

        requestID = messageHash;

        latestDeploymentRequestID[msg.sender] = requestID;

        totalDeploymentRequest++;

        // set solver reputation
        setReputation(solverAddress);

        // pick up deployment status since this is private deployment request, which can be picked only by refered worker
        DeploymentStatus memory deploymentStatus;
        deploymentStatus.status = Status.Pickup;
        deploymentStatus.deployWorkerAddr = privateWorkerAddress;

        requestDeploymentStatus[requestID] = deploymentStatus;

        emit RequestPrivateDeployment(msg.sender,privateWorkerAddress,solverAddress,messageHash, base64Proposal,serverURL);

        // emit accept deployment event since this deployment request is accepted by blueprint
        emit AcceptDeployment(requestID, privateWorkerAddress);
    }

    function submitProofOfDeployment(bytes32 requestID, string memory proofBase64) public{
        require (requestID.length > 0, "request ID is empty");
        require(requestDeploymentStatus[requestID].status != Status.Init,"request ID not exit");
        require(requestDeploymentStatus[requestID].deployWorkerAddr == msg.sender,"wrong worker address");

        // set deployment status into generatedProof
        requestDeploymentStatus[requestID].status = Status.GeneratedProof;

        // save deployment proof to mapping
        deploymentProof[requestID] = proofBase64;

        emit GeneratedProofOfDeployment(requestID, proofBase64);



    }

    function submitDeploymentRequest(bytes32 requestID) public returns (bool isAccepted) {
        require (requestID.length > 0, "request ID is empty");
        require(requestDeploymentStatus[requestID].status != Status.Init,"request ID not exit");
        require(requestDeploymentStatus[requestID].status != Status.Pickup,"request ID already pick by another worker, try different request id");

        // currently, do first come, first server, will do a better way in the future
        requestDeploymentStatus[requestID].status = Status.Pickup;
        requestDeploymentStatus[requestID].deployWorkerAddr = msg.sender;

        isAccepted = true;

        emit AcceptDeployment(requestID, requestDeploymentStatus[requestID].deployWorkerAddr);
    }


    // get latest deployment status
    function getDeploymentStatus(bytes32 requestID) public view returns (Status,address)  {
        return (requestDeploymentStatus[requestID].status,requestDeploymentStatus[requestID].deployWorkerAddr);
    }

    // get latest proposal request id
    function getLatestProposalRequestID(address addr) public view returns (bytes32) {

        return latestProposalRequestID[addr];
    }

    // get latest deployment request id
    function getLatestDeploymentRequestID(address addr) public view returns (bytes32) {

        return latestDeploymentRequestID[addr];
    }


}