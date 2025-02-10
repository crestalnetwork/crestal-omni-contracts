// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./Blueprint.sol";

contract BlueprintV4 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Blueprint {
    string public constant SIGNING_DOMAIN = "app.crestal.network";
    address public constant NFT_Contract_Address = address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578);

    function initialize() public reinitializer(4) {
        __Ownable_init(msg.sender);
        VERSION = "4.0.0";
        __EIP712_init(SIGNING_DOMAIN, VERSION);
        __UUPSUpgradeable_init();
        NFTContractAddress = NFT_Contract_Address;
    }

    // The _authorizeUpgrade function is required by the UUPSUpgradeable contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
