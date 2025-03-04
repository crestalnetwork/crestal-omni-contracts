// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./BlueprintCore.sol";

contract Blueprint is OwnableUpgradeable, BlueprintCore {
    event PaymentAddressAdded(address paymentAddress);
    event CreateAgentTokenCost(address paymentAddress, int256 cost);
    event UpdateAgentTokenCost(address paymentAddress, int256 cost);
    event CrestalWalletAddress(address crestalWalletAddress);

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

    function addWhitelistAddress(address whitelistAddress) public onlyOwner {
        whitelistUsers[whitelistAddress] = Status.Issued;
    }

    function deleteWhitelistAddress(address whitelistAddress) public onlyOwner {
        delete whitelistUsers[whitelistAddress];
    }

    function resetAgentCreationStatus(address userAddress, uint256 tokenId) public onlyOwner {
        whitelistUsers[userAddress] = Status.Issued;
        nftTokenIdMap[tokenId] = Status.Init;
    }

    // slither-disable-next-line costly-loop
    function removeWhitelistAddresses(address[] calldata removedAddress) public onlyOwner {
        for (uint256 i = 0; i < removedAddress.length; i++) {
            delete whitelistUsers[removedAddress[i]];
        }
    }

    function addPaymentAddress(address paymentAddress) public onlyOwner {
        require(paymentAddress != address(0), "Payment Address is invalid");
        paymentAddressesMp[PAYMENT_KEY].push(paymentAddress);

        emit PaymentAddressAdded(paymentAddress);
    }

    function setCreateAgentTokenCost(address paymentAddress, int256 cost) public onlyOwner {
        require(paymentAddress != address(0), "Payment Address is invalid");

        require(isValidatePaymentAddress(paymentAddress), "Payment Address is not added");

        paymentOpCostMp[paymentAddress][CREATE_AGENT_OP] = cost;

        emit CreateAgentTokenCost(paymentAddress, cost);
    }

    function setUpdateCreateAgentTokenCost(address paymentAddress, int256 cost) public onlyOwner {
        require(paymentAddress != address(0), "Payment Address is invalid");

        require(isValidatePaymentAddress(paymentAddress), "Payment Address is not added");

        paymentOpCostMp[paymentAddress][UPDATE_AGENT_OP] = cost;

        emit UpdateAgentTokenCost(paymentAddress, cost);
    }

    function setCrestalWalletAddress(address _crestalWalletAddress) public onlyOwner {
        require(_crestalWalletAddress != address(0), "Crestal Wallet Address is invalid");
        crestalWalletAddress = _crestalWalletAddress;

        emit CrestalWalletAddress(_crestalWalletAddress);
    }

    function isValidatePaymentAddress(address paymentAddress) internal view returns (bool) {
        // need to add paymentAddress before setting cost
        address[] memory paymentAddresses = paymentAddressesMp[PAYMENT_KEY];
        uint256 i = 0;
        for (; i < paymentAddresses.length; i++) {
            if (paymentAddresses[i] == paymentAddress) {
                return true;
            }
        }

        return false;
    }
}
