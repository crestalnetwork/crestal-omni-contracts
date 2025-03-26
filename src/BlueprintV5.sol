// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./Blueprint.sol";

contract BlueprintV5 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Blueprint {
    string public constant SIGNING_DOMAIN = "app.crestal.network";
    // no hand nation pass NFT contract address
    address public constant NFT_CONTRACT_ADDRESS = address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578);

    // default worker
    address public constant DEFAULT_WORKER = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);

    function initialize() public reinitializer(5) {
        __Ownable_init(msg.sender);
        VERSION = "5.0.0";
        __EIP712_init(SIGNING_DOMAIN, VERSION);
        __UUPSUpgradeable_init();

        // default worker setting
        defaultWorker = DEFAULT_WORKER;
        trustWorkerMp[DEFAULT_WORKER] = true;
    }

    // The _authorizeUpgrade function is required by the UUPSUpgradeable contract

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
