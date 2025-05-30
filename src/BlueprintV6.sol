// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./Blueprint.sol";

contract BlueprintV6 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Blueprint {
    string public constant SIGNING_DOMAIN = "nation.fun";

    function initialize() public reinitializer(6) {
        __Ownable_init(msg.sender);
        VERSION = "6.0.0";
        __EIP712_init(SIGNING_DOMAIN, VERSION);
        __UUPSUpgradeable_init();
    }

    // The _authorizeUpgrade function is required by the UUPSUpgradeable contract

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
