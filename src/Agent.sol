// src/Agent.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./Payment.sol";
import "./Blueprint.sol";

contract Agent is ERC2771Context {
    address public blueprintCore;

    event SetCopyAgentFee(bytes32 indexed agentRequestID, address userAddress, address tokenAddress, uint256 fee);
    event CopyAgentRequest(bytes32 indexed copyID, bytes32 indexed originalAgentRequestID, address userAddress);

    event UserTopUp(
        address indexed walletAddress, address feeCollectionWalletAddress, address tokenAddress, uint256 amount
    );

    event UserTopUpOther(
        address indexed ownerAddress,
        address indexed toAddress,
        address feeCollectionWalletAddress,
        address tokenAddress,
        uint256 amount
    );

    constructor(address _core, address trustedForwarder) ERC2771Context(trustedForwarder) {
        blueprintCore = _core;
    }

    function setCopyAgentFee(bytes32 agentRequestID, address tokenAddress, uint256 fee) external {
        require(fee > 0, "Fee must be greater than 0");
        require(Blueprint(blueprintCore).paymentAddressEnableMp(tokenAddress), "Invalid token address");
        address sender = _msgSender();
        require(Blueprint(blueprintCore).getDeploymentOwner(agentRequestID) == sender, "Not owner");

        Blueprint(blueprintCore).setCopyAgentFeeStorage(agentRequestID, tokenAddress, fee);
        emit SetCopyAgentFee(agentRequestID, sender, tokenAddress, fee);
    }

    function setCopyAgentFeeWithSig(bytes32 agentRequestID, address tokenAddress, uint256 fee, bytes memory signature)
        external
    {
        address owner = Blueprint(blueprintCore).getDeploymentOwner(agentRequestID);
        require(owner != address(0), "Invalid agentRequestID");
        require(fee > 0, "Fee must be greater than 0");
        require(Blueprint(blueprintCore).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        uint256 nonce = Blueprint(blueprintCore).getUserNonce(owner);
        bytes32 digest = Blueprint(blueprintCore).getSetCopyAgentFeeDigest(agentRequestID, tokenAddress, fee, nonce);
        address signer = Blueprint(blueprintCore).getSignerAddress(digest, signature);

        require(signer == owner, "Wrong owner signature");

        Blueprint(blueprintCore).setCopyAgentFeeStorage(agentRequestID, tokenAddress, fee);
        Blueprint(blueprintCore).incrementUserNonce(owner);

        emit SetCopyAgentFee(agentRequestID, owner, tokenAddress, fee);
    }

    function createCopyAgentRequest(bytes32 copyID, bytes32 originalAgentRequestID, address tokenAddress)
        public
        payable
    {
        createCopyAgentRequestCommon(copyID, originalAgentRequestID, tokenAddress, _msgSender());
    }

    function createCopyAgentRequestWithSig(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        bytes memory signature
    ) public payable {
        require(Blueprint(blueprintCore).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        // get digest
        bytes32 digest =
            Blueprint(blueprintCore).getCreateCopyAgentRequestDigest(copyID, originalAgentRequestID, tokenAddress);
        // get signer address
        address signer = Blueprint(blueprintCore).getSignerAddress(digest, signature);

        // get signer address, notice signer cannot be owner of the original agent request

        createCopyAgentRequestCommon(copyID, originalAgentRequestID, tokenAddress, signer);
    }

    function createCopyAgentRequestCommon(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        address userAddress
    ) internal {
        require(Blueprint(blueprintCore).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        address owner = Blueprint(blueprintCore).getDeploymentOwner(originalAgentRequestID);
        require(owner != address(0), "Invalid original agent request ID");

        uint256 fee = Blueprint(blueprintCore).copyAgentFeeMp(originalAgentRequestID, tokenAddress);
        require(fee > 0, "Copy Agent is not set by the owner");

        // check platformFee is set or not
        require(Blueprint(blueprintCore).platformCopyAgentFee() > 0, "Platform fee is not set");

        // calculate platform and creator fees
        uint256 platformFee =
            (fee * Blueprint(blueprintCore).platformCopyAgentFee()) / Blueprint(blueprintCore).factor();

        uint256 creatorFee = fee - platformFee;

        address feeWallet = Blueprint(blueprintCore).feeCollectionWalletAddress();

        // pay the platform fee to the fee collection wallet
        Blueprint(blueprintCore).forwardPayWithERC20(tokenAddress, platformFee, userAddress, feeWallet);

        // pay the creator fee to the owner of the original agent request
        Blueprint(blueprintCore).forwardPayWithERC20(tokenAddress, creatorFee, userAddress, owner);

        emit CopyAgentRequest(copyID, originalAgentRequestID, userAddress);
    }

    function createAgentWithToken(
        bytes32 projectId,
        string memory base64Proposal,
        address privateWorkerAddress,
        string memory serverURL,
        address tokenAddress
    ) public payable returns (bytes32 requestID) {
        requestID = Blueprint(blueprintCore).createAgent(
            _msgSender(), projectId, base64Proposal, privateWorkerAddress, serverURL, 0, tokenAddress
        );
    }

    function createAgentWithTokenWithSig(
        bytes32 projectId,
        string memory base64Proposal,
        address privateWorkerAddress,
        string memory serverURL,
        address tokenAddress,
        bytes memory signature
    ) public payable returns (bytes32 requestID) {
        // get EIP712 hash digest
        bytes32 digest = Blueprint(blueprintCore).getCreateAgentWithTokenDigest(
            projectId, base64Proposal, serverURL, privateWorkerAddress, tokenAddress
        );

        // get signer address
        address signerAddr = Blueprint(blueprintCore).getSignerAddress(digest, signature);

        requestID = Blueprint(blueprintCore).createAgent(
            signerAddr, projectId, base64Proposal, privateWorkerAddress, serverURL, 0, tokenAddress
        );
    }

    function updateWorkerDeploymentConfig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string memory updatedBase64Config
    ) public payable {
        Blueprint(blueprintCore).updateWorkerDeploymentConfigCommon(
            tokenAddress, _msgSender(), projectId, requestID, updatedBase64Config
        );
    }

    function updateWorkerDeploymentConfigWithSig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string memory updatedBase64Config,
        bytes memory signature
    ) public payable {
        address owner = Blueprint(blueprintCore).getDeploymentOwner(requestID);
        require(owner != address(0), "Invalid requestID");

        // get EIP712 hash digest
        bytes32 digest = Blueprint(blueprintCore).getUpdateWorkerConfigDigest(
            tokenAddress, projectId, requestID, updatedBase64Config, Blueprint(blueprintCore).getUserNonce(owner)
        );

        // get signer address
        address signerAddr = Blueprint(blueprintCore).getSignerAddress(digest, signature);

        // check if signer address is owner of requestID
        require(signerAddr == owner, "Invalid signature");

        Blueprint(blueprintCore).updateWorkerDeploymentConfigCommon(
            tokenAddress, signerAddr, projectId, requestID, updatedBase64Config
        );

        Blueprint(blueprintCore).incrementUserNonce(owner);
    }

    function userTopUp(address tokenAddress, uint256 amount) public payable {
        Blueprint(blueprintCore).topUp(msg.sender, tokenAddress, amount);
        address feeCollectionWalletAddress = Blueprint(blueprintCore).feeCollectionWalletAddress();
        emit UserTopUp(msg.sender, feeCollectionWalletAddress, tokenAddress, amount);
    }

    function userTopUpOther(address userAddress, address tokenAddress, uint256 amount) public payable {
        Blueprint(blueprintCore).topUp(userAddress, tokenAddress, amount);
        address feeCollectionWalletAddress = Blueprint(blueprintCore).feeCollectionWalletAddress();
        emit UserTopUpOther(msg.sender, userAddress, feeCollectionWalletAddress, tokenAddress, amount);
    }
}
