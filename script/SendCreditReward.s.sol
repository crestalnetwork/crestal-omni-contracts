// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BlueprintV6} from "../src/BlueprintV6.sol";
import {StrSlice, toSlice} from "solidity-stringutils/StrSlice.sol";

contract SendCreditRewardScript is Script {
    using {toSlice} for string;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address proxyAddr = vm.envAddress("PROXY_ADDRESS");
        BlueprintV6 proxy = BlueprintV6(proxyAddr);

        string memory rewardFile = vm.envString("REWARD_WALLETS");
        while (true) {
            string memory line = vm.readLine(rewardFile);
            if (bytes(line).length == 0) {
                break;
            }

            StrSlice s = line.toSlice();
            (bool found, StrSlice firstSlice, StrSlice secondSlice) = s.splitOnce(toSlice(","));
            if (!found) {
                continue;
            }

            address addr = vm.parseAddress(firstSlice.toString());
            uint256 amount = vm.parseUint(secondSlice.toString());
            proxy.creditReward(addr, amount);
        }

        vm.stopBroadcast();
    }
}
