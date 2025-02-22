// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./Blueprint.sol";

contract BlueprintCore is OwnableUpgradeable, Blueprint {
    function setNFTContractAddress(address _nftContractAddress) public onlyOwner {
        nftContractAddress = _nftContractAddress;
    }

    function setWhitelistAddresses(address[] calldata _whitelistAddress) public onlyOwner {
        for (uint256 i = 0; i < _whitelistAddress.length; i++) {
            whitelistUsers[_whitelistAddress[i]] = Status.Issued;
        }
    }

    function addWhitelistAddress(address _whitelistAddress) public onlyOwner {
        whitelistUsers[_whitelistAddress] = Status.Issued;
    }

    function deleteWhitelistAddress(address _whitelistAddress) public onlyOwner {
        delete whitelistUsers[_whitelistAddress];
    }

    function resetAgentCreationStatus(address userAddress, uint256 tokenId) public onlyOwner {
        whitelistUsers[userAddress] = Status.Issued;
        nftTokenIdMap[tokenId] = Status.Init;
    }

    function removeWhitelistAddresses(address[] calldata _removedAddress) public onlyOwner {
        for (uint256 i = 0; i < _removedAddress.length; i++) {
            delete whitelistUsers[_removedAddress[i]];
        }
    }
}
