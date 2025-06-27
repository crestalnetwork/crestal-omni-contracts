// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./NewBlueprintCore.sol";

contract NewBlueprint is NewBlueprintCore {
    string public version;

    event PaymentAddressAdded(address paymentAddress);
    event CreateAgentTokenCost(address paymentAddress, uint256 cost);
    event UpdateAgentTokenCost(address paymentAddress, uint256 cost);
    event RemovePaymentAddress(address paymentAddress);
    event FeeCollectionWalletAddress(address feeCollectionWalletAddress);
    event SetWorkerAdmin(address workerAdmin);
    event UpdateWorker(address workerAddress, bool isTrusted);
    event CreditReward(address indexed userAddress, uint256 amount);
    event SetGlobalPlatformFee(uint256 baseFee, address paymentAddress);
    event SetAdminContract(address agentContract);
    event RemoveAdminContract(address agentContract);

    constructor(string memory _version) {
        version = _version;
        factor = 1000; // default factor is 1000
    }

    modifier isAdmin() {
        // slither-disable-next-line timestamp
        require(msg.sender == workerAdmin, "Not an admin or owner");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == workerAdmin, "Not the contract owner");
        _;
    }

    // slither-disable-next-line naming-convention
    function setNFTContractAddress(address _nftContractAddress) public onlyOwner {
        require(_nftContractAddress != address(0), "NFT Contract is invalid");
        nftContractAddress = _nftContractAddress;
    }

    function setWhitelistAddresses(address[] calldata whitelistAddress) public onlyOwner {
        for (uint256 i = 0; i < whitelistAddress.length; i++) {
            whitelistUsers[whitelistAddress[i]] = Status.Issued;
        }
    }

    // slither-disable-next-line costly-loop
    function removeWhitelistAddresses(address[] calldata removedAddress) public onlyOwner {
        for (uint256 i = 0; i < removedAddress.length; i++) {
            delete whitelistUsers[removedAddress[i]];
        }
    }

    function addPaymentAddress(address paymentAddress) public onlyOwner {
        require(!paymentAddressEnableMp[paymentAddress], "Payment address was already added");

        // remove previously pushed entries
        for (uint256 i = 0; i < paymentAddressesMp[PAYMENT_KEY].length; i++) {
            if (paymentAddressesMp[PAYMENT_KEY][i] == paymentAddress) {
                delete paymentAddressesMp[PAYMENT_KEY][i];
            }
        }

        // push latest one
        paymentAddressesMp[PAYMENT_KEY].push(paymentAddress);
        paymentAddressEnableMp[paymentAddress] = true;

        emit PaymentAddressAdded(paymentAddress);
    }

    function setCreateAgentTokenCost(address paymentAddress, uint256 cost) public onlyOwner {
        require(paymentAddressEnableMp[paymentAddress], "Payment Address is not added");

        paymentOpCostMp[paymentAddress][CREATE_AGENT_OP] = cost;

        emit CreateAgentTokenCost(paymentAddress, cost);
    }

    function setUpdateCreateAgentTokenCost(address paymentAddress, uint256 cost) public onlyOwner {
        require(paymentAddressEnableMp[paymentAddress], "Payment Address is not added");

        paymentOpCostMp[paymentAddress][UPDATE_AGENT_OP] = cost;

        emit UpdateAgentTokenCost(paymentAddress, cost);
    }

    function removePaymentAddress(address paymentAddress) public onlyOwner {
        require(paymentAddressEnableMp[paymentAddress], "Payment Address is not added");

        // soft remove
        paymentAddressEnableMp[paymentAddress] = false;

        emit RemovePaymentAddress(paymentAddress);
    }

    // slither-disable-next-line naming-convention
    function setFeeCollectionWalletAddress(address _feeCollectionWalletAddress) public onlyOwner {
        require(_feeCollectionWalletAddress != address(0), "Fee collection Wallet Address is invalid");
        feeCollectionWalletAddress = _feeCollectionWalletAddress;

        emit FeeCollectionWalletAddress(_feeCollectionWalletAddress);
    }

    function updateWorker(address workerAddress, bool isTrusted) public isAdmin {
        require(workerAddress != address(0), "Worker address is invalid");

        trustWorkerMp[workerAddress] = isTrusted;

        emit UpdateWorker(workerAddress, isTrusted);
    }

    // reset previous unclean workers
    function resetWorkers() public isAdmin {
        resetWorkerAddresses();
    }

    function creditReward(address userAddress, uint256 amount) public isAdmin {
        require(userAddress != address(0), "User address is invalid");
        require(amount > 0, "Amount should be greater than zero");

        emit CreditReward(userAddress, amount);
    }

    function setAdminContract(address _adminContract) public onlyOwner {
        require(_adminContract != address(0), "Admin contract address is invalid");
        adminContracts[_adminContract] = true;
        emit SetAdminContract(_adminContract);
    }

    function removeAdminContract(address _adminContract) public onlyOwner {
        require(_adminContract != address(0), "Admin contract address is invalid");
        delete adminContracts[_adminContract];
        emit RemoveAdminContract(_adminContract);
    }

    // nation token fee is a global fee that applies to all agents
    function setGlobalPlatformFee(uint256 baseFee, address paymentAddress) public isAdmin {
        // base factor should be greater or equal than 10
        require(paymentAddressEnableMp[paymentAddress], "Payment Address is not added");
        platformFee[paymentAddress] = baseFee;
        emit SetGlobalPlatformFee(baseFee, paymentAddress);
    }
}
