// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./Blueprint.sol";

contract BlueprintV6 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Blueprint {
    string public constant SIGNING_DOMAIN = "nation.fun";

    /// @custom:oz-upgrades-validate-as-initializer
    function initialize() public reinitializer(6) {
        VERSION = "6.0.0";
        // __Ownable_init(msg.sender); is called inside this now for chain init
        __Blueprint_init(SIGNING_DOMAIN, VERSION);
        __UUPSUpgradeable_init();
    }

    // The _authorizeUpgrade function is required by the UUPSUpgradeable contract

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
