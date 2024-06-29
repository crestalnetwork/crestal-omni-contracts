// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

contract blueprint {

    enum Status {
        Init,
        Issued,
        Pickup,
        Deploying,
        Deployed,
        GenerateProof
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

    uint256 public factor;
    uint256 public totalProposalRequest;
    uint256 public totalDeploymentRequest;

    event RequestProposal(address indexed walletAddress, bytes32 indexed messageHash, string base64RecParam, string serverURL);
    event RequestDeployment(address indexed walletAddress, bytes32 indexed messageHash,string base64Proposal, string serverURL);

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
    //    associated base64 string: eyJ0eXBlcyI6WyJEQSJdLCJ1cHRpbWUiOjAsImxhdGVuY3kiOjAsInRocm91Z2hwdXQiOjIwLCJlcnJvcl9yYXRlIjowLjEsImNvc3QiOjQsImluaXRfY29zdCI6MCwibWFpbnRlbmFuY2VfY29zdCI6MCwiZXh0cmFfYXR0cmlidXRlIjoiIn0=
//        type DAProposal struct {
//            ID              int     `json:"id,omitempty" example:"1"`
//            DAName          string  `json:"da_name,omitempty" example:"celestia"`
//            Latency         float64 `json:"latency"`
//            MaxThroughput   float64 `json:"max_throughput,omitempty" example:"10.5"` // max throughput unit: mb/s
//            FinalityTime    float64 `json:"finality_time,omitempty" example:"2.0"`   // block confirmation time in second
//            BlockTime       float64 `json:"block_time,omitempty" example:"10"`
//            CostPerBlock    float64 `json:"cost_per_block,omitempty" `
//            SendBlobLatency float64 `json:"send_blob_latency,omitempty" `
//            demo : highly recommend use above field to do recommendation
//
//            UpTime          float64        `json:"uptime,omitempty" example:"10"` // SLA
//            ErrorRate       float64        `json:"error_rate,omitempty" example:"0.02"`
//            Cost            float64        `json:"cost,omitempty" example:"10"`
//            InitCost        float64        `json:"init_cost,omitempty"`
//            MaintenanceCost float64        `json:"maintenance_cost,omitempty"`
//            ExtraAttribute  datatypes.JSON `json:"extra_attribute,omitempty" gorm:"type:json"`
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

        emit RequestDeployment(msg.sender,messageHash, base64Proposal,serverURL);

    }

    function submitDeploymentRequest(bytes32 requestID) public returns (bool isAccepted) {
        require (requestID.length > 0, "request ID is empty");
        require(requestDeploymentStatus[requestID].status != Status.Init,"request ID not exit");
        require(requestDeploymentStatus[requestID].status != Status.Pickup,"request ID already pick by another worker, try different request id");

        // currently, do first come, first server, will do a better way in the future
        requestDeploymentStatus[requestID].status = Status.Pickup;
        requestDeploymentStatus[requestID].deployWorkerAddr = msg.sender;

        isAccepted = true;
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