// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Blueprint.sol";

contract BlueprintV7 is Initializable, Blueprint {
    string public constant SIGNING_DOMAIN = "nation.fun";

    /// @custom:oz-upgrades-validate-as-initializer
    function initialize() public reinitializer(7) {
        VERSION = "7.0.0";
        __Blueprint_init(SIGNING_DOMAIN, VERSION);
    }
}
