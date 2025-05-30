// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./BlueprintCore.sol";

contract Blueprint is OwnableUpgradeable, BlueprintCore {
    event PaymentAddressAdded(address paymentAddress);
    event CreateAgentTokenCost(address paymentAddress, uint256 cost);
    event UpdateAgentTokenCost(address paymentAddress, uint256 cost);
    event RemovePaymentAddress(address paymentAddress);
    event FeeCollectionWalletAddress(address feeCollectionWalletAddress);
    event SetWorkerAdmin(address workerAdmin);
    event UpdateWorker(address workerAddress, bool isTrusted);
    event CreditReward(address indexed userAddress, uint256 amount);

    modifier isAdmin() {
        // slither-disable-next-line timestamp
        require(msg.sender == workerAdmin || msg.sender == owner(), "Not an admin or owner");
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

    // slither-disable-next-line naming-convention
    function setWorkerAdmin(address _workerAdmin) public onlyOwner {
        require(_workerAdmin != address(0), "Worker Admin is invalid");
        workerAdmin = _workerAdmin;

        emit SetWorkerAdmin(_workerAdmin);
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
}
