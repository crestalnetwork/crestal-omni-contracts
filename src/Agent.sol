// src/Agent.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./Payment.sol";
import "./Storage.sol";
import "./EIP712.sol";

contract Agent is Storage, Payment, EIP712 {
    string public version;

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

    constructor(string memory _version) {
        version = _version;
        factor = 1000; // default factor for fee calculation
    }

    function setCopyAgentFee(bytes32 agentRequestID, address tokenAddress, uint256 fee) external {
        require(paymentAddressEnableMp[tokenAddress], "Invalid token address");
        require(_getDeploymentOwner(agentRequestID) == msg.sender, "Not owner");

        copyAgentFeeMp[agentRequestID][tokenAddress] = fee;
        emit SetCopyAgentFee(agentRequestID, msg.sender, tokenAddress, fee);
    }

    function setCopyAgentFeeWithSig(bytes32 agentRequestID, address tokenAddress, uint256 fee, bytes memory signature)
        external
    {
        address owner = _getDeploymentOwner(agentRequestID);
        require(owner != address(0), "Invalid agentRequestID");
        require(paymentAddressEnableMp[tokenAddress], "Invalid token address");

        uint256 nonce = _getUserNonce(owner);
        bytes32 digest = getSetCopyAgentFeeDigest(agentRequestID, tokenAddress, fee, nonce);
        address signer = getSignerAddress(digest, signature);

        require(signer == owner, "Wrong owner signature");

        copyAgentFeeMp[agentRequestID][tokenAddress] = fee;
        _setUserNonce(owner, nonce + 1);

        emit SetCopyAgentFee(agentRequestID, owner, tokenAddress, fee);
    }

    function createCopyAgentRequest(bytes32 copyID, bytes32 originalAgentRequestID, address tokenAddress)
        public
        payable
    {
        createCopyAgentRequestCommon(copyID, originalAgentRequestID, tokenAddress, msg.sender);
    }

    function createCopyAgentRequestWithSig(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        bytes memory signature
    ) public payable {
        require(paymentAddressEnableMp[tokenAddress], "Invalid token address");

        bytes32 digest = getCreateCopyAgentRequestDigest(copyID, originalAgentRequestID, tokenAddress);
        address signer = getSignerAddress(digest, signature);

        // get signer address, notice signer cannot be owner of the original agent request
        createCopyAgentRequestCommon(copyID, originalAgentRequestID, tokenAddress, signer);
    }

    function createCopyAgentRequestCommon(
        bytes32 copyID,
        bytes32 originalAgentRequestID,
        address tokenAddress,
        address userAddress
    ) internal {
        // ensure token is enabled
        require(paymentAddressEnableMp[tokenAddress], "Invalid token address");

        // fetch and validate owner
        address owner = _getDeploymentOwner(originalAgentRequestID);
        require(owner != address(0), "Invalid original agent request ID");

        // fetch and validate platform fee
        uint256 platformFee = platformFee[tokenAddress];
        require(platformFee > 0, "Platform fee is not set");

        // compute total and creator fees
        uint256 totalFee = getCreateCopyAgentFee(originalAgentRequestID, tokenAddress);
        uint256 creatorFee = totalFee - platformFee;

        // perform payments
        // pay platform fee to the fee wallet
        payWithERC20(tokenAddress, platformFee, userAddress, feeCollectionWalletAddress);
        // if creator fee is greater than 0, pay to the owner
        if (creatorFee > 0) {
            payWithERC20(tokenAddress, creatorFee, userAddress, owner);
        }

        emit CopyAgentRequest(copyID, originalAgentRequestID, userAddress, totalFee);
    }

    function getCreateCopyAgentFee(bytes32 originalAgentRequestID, address tokenAddress)
        public
        view
        returns (uint256)
    {
        // ensure the token is enabled for payments
        require(paymentAddressEnableMp[tokenAddress], "Invalid token address");

        // read the stored copy-agent fee and platform fee
        uint256 creatorFee = copyAgentFeeMp[originalAgentRequestID][tokenAddress];
        uint256 platformValue = platformFee[tokenAddress];

        // compute total: creatorFee * platform / factor + platform
        return (creatorFee * platformValue) / factor + platformValue;
    }

    function topUp(address toUserAddress, address tokenAddress, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");

        require(paymentAddressEnableMp[tokenAddress], "Payment address is not valid");

        // update user top up
        userTopUpMp[toUserAddress][tokenAddress] += amount;

        if (tokenAddress == address(0)) {
            require(msg.value == amount, "Native token amount mismatch");

            // payment to fee collection wallet address with ether
            payWithNativeToken(payable(feeCollectionWalletAddress), amount);
        } else {
            // payment to feeCollectionWalletAddress with token, fromAddress always from msg.sender
            payWithERC20(tokenAddress, amount, msg.sender, feeCollectionWalletAddress);
        }
    }

    function userTopUp(address tokenAddress, uint256 amount) public payable {
        topUp(msg.sender, tokenAddress, amount);
        emit UserTopUp(msg.sender, feeCollectionWalletAddress, tokenAddress, amount);
    }

    function userTopUpOther(address userAddress, address tokenAddress, uint256 amount) public payable {
        topUp(userAddress, tokenAddress, amount);
        emit UserTopUpOther(msg.sender, userAddress, feeCollectionWalletAddress, tokenAddress, amount);
    }
}
