// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BlueprintV5} from "../src/BlueprintV5.sol";

contract UpdatePaymentScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        address paymentTokenAddr = vm.envAddress("PAYMENT_TOKEN_ADDRESS");
        uint256 createCost = vm.envUint("CREATE_TOKEN_AMOUNT");
        uint256 updateCost = vm.envUint("UPDATE_TOKEN_AMOUNT");
        bool add = vm.envOr("NEW_PAYMENT_TOKEN", false);

        BlueprintV5 proxy = BlueprintV5(proxyAddr);
        if (add) {
            proxy.addPaymentAddress(paymentTokenAddr);
        }
        proxy.setCreateAgentTokenCost(paymentTokenAddr, createCost);
        proxy.setUpdateCreateAgentTokenCost(paymentTokenAddr, updateCost);

        vm.stopBroadcast();
    }
}
