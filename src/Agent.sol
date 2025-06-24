// src/Agent.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./Payment.sol";
import "./Blueprint.sol";

contract Agent is ERC2771Context, Payment {
    address public blueprintStorageProxy;
    address public trustRouter;
    string public VERSION;

    event SetCopyAgentFee(bytes32 indexed agentRequestID, address userAddress, address tokenAddress, uint256 fee);
    event CopyAgentRequest(
        bytes32 indexed copyID, bytes32 indexed originalAgentRequestID, address userAddress, uint256 totalFee
    );

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

    constructor(address _blueprintStorageProxy, address _trustedForwarder, string memory _version)
        ERC2771Context(_trustedForwarder)
    {
        trustRouter = _trustedForwarder;
        blueprintStorageProxy = _blueprintStorageProxy;
        VERSION = _version;
    }

    function setCopyAgentFee(bytes32 agentRequestID, address tokenAddress, uint256 fee) external {
        require(Blueprint(blueprintStorageProxy).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        address sender = _msgSender();
        require(Blueprint(blueprintStorageProxy).getDeploymentOwner(agentRequestID) == sender, "Not owner");

        Blueprint(blueprintStorageProxy).setCopyAgentFeeStorage(agentRequestID, tokenAddress, fee);
        emit SetCopyAgentFee(agentRequestID, sender, tokenAddress, fee);
    }

    function setCopyAgentFeeWithSig(bytes32 agentRequestID, address tokenAddress, uint256 fee, bytes memory signature)
        external
    {
        address owner = Blueprint(blueprintStorageProxy).getDeploymentOwner(agentRequestID);
        require(owner != address(0), "Invalid agentRequestID");
        require(Blueprint(blueprintStorageProxy).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        uint256 nonce = Blueprint(blueprintStorageProxy).getUserNonce(owner);
        bytes32 digest =
            Blueprint(blueprintStorageProxy).getSetCopyAgentFeeDigest(agentRequestID, tokenAddress, fee, nonce);
        address signer = Blueprint(blueprintStorageProxy).getSignerAddress(digest, signature);

        require(signer == owner, "Wrong owner signature");

        Blueprint(blueprintStorageProxy).setCopyAgentFeeStorage(agentRequestID, tokenAddress, fee);
        Blueprint(blueprintStorageProxy).incrementUserNonce(owner);

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
        require(Blueprint(blueprintStorageProxy).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        // get digest
        bytes32 digest = Blueprint(blueprintStorageProxy).getCreateCopyAgentRequestDigest(
            copyID, originalAgentRequestID, tokenAddress
        );
        // get signer address
        address signer = Blueprint(blueprintStorageProxy).getSignerAddress(digest, signature);

        // get signer address, notice signer cannot be owner of the original agent request

        createCopyAgentRequestCommon(copyID, originalAgentRequestID, tokenAddress, signer);
    }

    function createCopyAgentRequestCommon(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        address userAddress
    ) internal {
        require(Blueprint(blueprintStorageProxy).paymentAddressEnableMp(tokenAddress), "Invalid token address");

        address owner = Blueprint(blueprintStorageProxy).getDeploymentOwner(originalAgentRequestID);
        require(owner != address(0), "Invalid original agent request ID");

        uint256 platformFee = Blueprint(blueprintStorageProxy).platformFee(tokenAddress);
        // check platformFee is set or not
        require(platformFee > 0, "Platform fee is not set");
        // calculate platform and creator fees
        uint256 totalFee = getCreateCopyAgentFee(originalAgentRequestID, tokenAddress);
        uint256 creatorFee = totalFee - platformFee;

        address feeWallet = Blueprint(blueprintStorageProxy).feeCollectionWalletAddress();
        address fromAddr = getPaymentFromAddress();
        if (fromAddr != address(this)) {
            // if the payment is not from the agent contract, we use the user address
            fromAddr = userAddress;
        }
        // pay the platform fee to the fee collection wallet
        payWithERC20(tokenAddress, platformFee, fromAddr, feeWallet);

        // pay the creator fee to the owner of the original agent request
        if (creatorFee > 0) {
            // if creator fee is greater than 0, we pay the creator fee to the owner
            payWithERC20(tokenAddress, creatorFee, fromAddr, owner);
        }

        emit CopyAgentRequest(copyID, originalAgentRequestID, userAddress, totalFee);
    }

    function getCreateCopyAgentFee(bytes32 originalAgentRequestID, address tokenAddress)
        public
        view
        returns (uint256)
    {
        require(Blueprint(blueprintStorageProxy).paymentAddressEnableMp(tokenAddress), "Invalid token address");
        uint256 fee = Blueprint(blueprintStorageProxy).copyAgentFeeMp(originalAgentRequestID, tokenAddress);
        uint256 platformFee = Blueprint(blueprintStorageProxy).platformFee(tokenAddress);
        return (fee * platformFee) / Blueprint(blueprintStorageProxy).factor() + platformFee;
    }

    function createAgentWithToken(
        bytes32 projectId,
        string memory base64Proposal,
        address privateWorkerAddress,
        string memory serverURL,
        address tokenAddress
    ) public payable returns (bytes32 requestID) {
        //todo: migrate payment logic
        requestID = Blueprint(blueprintStorageProxy).createAgent(
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
        bytes32 digest = Blueprint(blueprintStorageProxy).getCreateAgentWithTokenDigest(
            projectId, base64Proposal, serverURL, privateWorkerAddress, tokenAddress
        );

        // get signer address
        address signerAddr = Blueprint(blueprintStorageProxy).getSignerAddress(digest, signature);

        //todo: migrate payment logic
        requestID = Blueprint(blueprintStorageProxy).createAgent(
            signerAddr, projectId, base64Proposal, privateWorkerAddress, serverURL, 0, tokenAddress
        );
    }

    function updateWorkerDeploymentConfig(
        address tokenAddress,
        bytes32 projectId,
        bytes32 requestID,
        string memory updatedBase64Config
    ) public payable {
        //todo: migrate payment logic
        Blueprint(blueprintStorageProxy).updateWorkerDeploymentConfigCommon(
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
        address owner = Blueprint(blueprintStorageProxy).getDeploymentOwner(requestID);
        require(owner != address(0), "Invalid requestID");

        // get EIP712 hash digest
        bytes32 digest = Blueprint(blueprintStorageProxy).getUpdateWorkerConfigDigest(
            tokenAddress,
            projectId,
            requestID,
            updatedBase64Config,
            Blueprint(blueprintStorageProxy).getUserNonce(owner)
        );

        // get signer address
        address signerAddr = Blueprint(blueprintStorageProxy).getSignerAddress(digest, signature);

        // check if signer address is owner of requestID
        require(signerAddr == owner, "Invalid signature");
        //todo: migrate payment logic
        Blueprint(blueprintStorageProxy).updateWorkerDeploymentConfigCommon(
            tokenAddress, signerAddr, projectId, requestID, updatedBase64Config
        );

        Blueprint(blueprintStorageProxy).incrementUserNonce(owner);
    }

    function topUp(address toUserAddress, address tokenAddress, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");

        require(Blueprint(blueprintStorageProxy).paymentAddressEnableMp(tokenAddress), "Payment address is not valid");

        // update user top up
        Blueprint(blueprintStorageProxy).AddUserTopUpAmount(toUserAddress, tokenAddress, amount);

        address feeCollectionWalletAddress = Blueprint(blueprintStorageProxy).feeCollectionWalletAddress();

        if (tokenAddress == address(0)) {
            require(msg.value == amount, "Native token amount mismatch");

            // payment to fee collection wallet address with ether
            payWithNativeToken(payable(feeCollectionWalletAddress), amount);
        } else {
            // payment to feeCollectionWalletAddress with token, fromAddress always from msg.sender, either router or real user
            payWithERC20(tokenAddress, amount, getPaymentFromAddress(), feeCollectionWalletAddress);
        }
    }

    function getPaymentFromAddress() internal view returns (address) {
        // payment goes to router and router transfer fund into agent contract and then agent contract process from here
        // if the sender is the trust router, we use the agent contract address as the from address
        // otherwise, we use the real user address
        return (msg.sender == trustRouter) ? address(this) : _msgSender();
    }

    function userTopUp(address tokenAddress, uint256 amount) public payable {
        topUp(_msgSender(), tokenAddress, amount);
        emit UserTopUp(
            _msgSender(), Blueprint(blueprintStorageProxy).feeCollectionWalletAddress(), tokenAddress, amount
        );
    }

    function userTopUpOther(address userAddress, address tokenAddress, uint256 amount) public payable {
        topUp(userAddress, tokenAddress, amount);
        emit UserTopUpOther(
            _msgSender(),
            userAddress,
            Blueprint(blueprintStorageProxy).feeCollectionWalletAddress(),
            tokenAddress,
            amount
        );
    }
}
