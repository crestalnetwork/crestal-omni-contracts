// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Payment} from "./Payment.sol";
import {Storage} from "./Storage.sol";
import {Agent} from "./Agent.sol";

/// @title RouterV1 - EIP-2771 Forwarder and Router for Agent and Blueprint
/// @notice Forwards all public/external functions of Agent and Blueprint, appending the original sender for EIP-2771 meta-tx compatibility
contract RouterV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Storage {
    address public agent;
    address public blueprint;
    address public worker;
    // selector => target contract
    mapping(bytes4 => address) public selectorToTarget;

    function initialize() public reinitializer(1) {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        VERSION = "1.0.0";
    }

    function setAgent(address _agent) external onlyOwner {
        agent = _agent;
    }

    function setBlueprint(address _blueprint) external onlyOwner {
        blueprint = _blueprint;
        factor = 1000; // Reset factor to default
        workerAdmin = msg.sender; // Set the worker admin to the owner by default
    }

    function setWorker(address _worker) external onlyOwner {
        worker = _worker;
    }

    function setBlueprintAdmin(address _blueprintAdmin) external onlyOwner {
        require(_blueprintAdmin != address(0), "Blueprint admin cannot be zero address");
        workerAdmin = _blueprintAdmin;
    }

    // The _authorizeUpgrade function is required by the UUPSUpgradeable contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setSelectorTarget(bytes4 selector, address target) external onlyOwner {
        require(target == agent || target == blueprint, "Target must be agent or blueprint");
        selectorToTarget[selector] = target;
    }

    // Batch register selectors for convenience
    function setSelectorTargets(bytes4[] calldata selectors, address target) external onlyOwner {
        require(target == agent || target == blueprint, "Target must be agent or blueprint");
        for (uint256 i = 0; i < selectors.length; i++) {
            selectorToTarget[selectors[i]] = target;
        }
    }

    /// @dev Fallback for all calls: delegate into N
    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }

    function _delegate() internal {
        address target = selectorToTarget[msg.sig];
        if (target == address(0)) {
            // default to blueprint if no specific target is set
            target = blueprint;
        }

        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            calldatacopy(0, 0, calldatasize())
            // Delegatecall into the target contract
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            // Copy the returned data
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
