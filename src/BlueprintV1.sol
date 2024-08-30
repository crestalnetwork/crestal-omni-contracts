// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Blueprint.sol";

contract BlueprintV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Blueprint {
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        VERSION = "1.0.0";
    }

    // The _authorizeUpgrade function is required by the UUPSUpgradeable contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
