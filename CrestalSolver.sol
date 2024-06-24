// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

contract CrestalSolver {
    struct Solver {
        // string proposalHash;
        uint256 reputation;
    }

    bytes32 private messageHash;
    mapping(address => bytes32) public latestRequestID;
    mapping (address => Solver) public solverReputation;

    uint256 public factor;
    uint256 public totalRequest;
    event RequestProposal(address indexed walletAddress, bytes32 indexed messageHash, string data, string serverURL);

    constructor() {
        // set the factor, used for float type calculation
        factor = 10000;
        totalRequest++;
    }
    // get solver reputation
     function getReputation(address addr) public view returns (uint256) {
        return solverReputation[addr].reputation;
     }

     // set solver reputation
     function setReputation(address solverAddr) public returns (uint256 reputation) {
        // get the solver reputation
        Solver memory solver;
        solver = solverReputation[solverAddr];

        if (solver.reputation <  6 * factor ) {
            solver.reputation += factor;
        } else {
            if (totalRequest > 1000) {
                 solver.reputation +=  (solver.reputation - 6 * factor) / totalRequest;
            } else {
                 solver.reputation +=  (solver.reputation - 6 * factor) / 1000;
            }
        }

        reputation = solver.reputation;

        solverReputation[solverAddr] = solver;

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

    function createProposalRequest(string memory data, string memory serverURL) public returns (bytes32 requestID) {
        // generate unique hash
        require (bytes(serverURL).length > 0, "server URL is empty");
        require (bytes(data).length >  0, "data is empty");

        messageHash = keccak256(abi.encodePacked(block.timestamp,msg.sender));

        requestID = messageHash;

        latestRequestID[msg.sender] = requestID;

        totalRequest++;

        emit RequestProposal(msg.sender,messageHash,data,serverURL);

    }


   // get latest reqeust id
   function getlatestRequstID(address addr) public view returns (bytes32) {

      return latestRequestID[addr];
   }

}