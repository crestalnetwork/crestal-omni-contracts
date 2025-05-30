pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BlueprintV6} from "../src/BlueprintV6.sol";
import {BlueprintCore} from "../src/BlueprintCore.sol";
import {Blueprint} from "../src/Blueprint.sol";
import {stdError} from "forge-std/StdError.sol";
import {MockERC20} from "./MockERC20.sol";

contract BlueprintTest is Test {
    BlueprintV6 public blueprint;
    MockERC20 public mockToken;
    bytes32 public projectId;
    address public workerAddress;
    address public dummyAddress;
    uint256 signerPrivateKey;

    function setUp() public {
        blueprint = new BlueprintV6();
        blueprint.initialize(); // mimic upgradeable contract deploy behavior

        mockToken = new MockERC20();

        // set crestal wallet address
        blueprint.setFeeCollectionWalletAddress(address(0x7D8be0Dd8915E3511fFDDABDD631812be824f578));

        projectId = bytes32(0x2723a34e38d0f0aa09ce626f00aa23c0464b52c75516cf3203cc4c9afeaf2980);
        workerAddress = address(0x4d6585D89F889F29f77fd7Dd71864269BA1B31df);
        dummyAddress = address(0);
        signerPrivateKey = 0xA11CE;
    }

    function test_userTopUp() public {
        uint256 topUpAmount = 100 * 10 ** 18;

        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));

        // Mint tokens to the test account
        mockToken.mint(address(this), topUpAmount);

        // Approve the blueprint contract to spend tokens
        mockToken.approve(address(blueprint), topUpAmount);

        // Expect the UserTopUp event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.UserTopUp(
            address(this), blueprint.feeCollectionWalletAddress(), address(mockToken), topUpAmount
        );

        // Call the userTopUp function
        blueprint.userTopUp(address(mockToken), topUpAmount);

        // Verify the top-up amount
        uint256 userBalance = blueprint.userTopUpMp(address(this), address(mockToken));
        assertEq(userBalance, topUpAmount, "User top-up amount is incorrect");

        // Verify the token transfer
        uint256 blueprintBalance = mockToken.balanceOf(address(blueprint.feeCollectionWalletAddress()));
        assertEq(blueprintBalance, topUpAmount, "Blueprint fee collection wallet balance is incorrect");

        // verify user balance after top up
        uint256 balance = mockToken.balanceOf(address(this));
        assertEq(balance, 0, "sender does not have the correct token balance after top up");

        // Add the payment address for eth
        blueprint.addPaymentAddress(address(0));

        topUpAmount = 1 ether;

        // Expect the UserTopUp event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.UserTopUp(address(this), blueprint.feeCollectionWalletAddress(), address(0), topUpAmount);

        // Call the userTopUp function with native token
        blueprint.userTopUp{value: topUpAmount}(address(0), topUpAmount);

        // Verify the native token transfer
        uint256 blueprintEthBalance = blueprint.feeCollectionWalletAddress().balance;
        assertEq(blueprintEthBalance, topUpAmount, "Blueprint fee collection wallet balance is incorrect");

        // Verify the top-up amount
        userBalance = blueprint.userTopUpMp(address(this), address(0));
        assertEq(userBalance, topUpAmount, "User top-up amount is incorrect");
    }

    function test_userTopUpOther() public {
        uint256 topUpAmount = 100 * 10 ** 18;

        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));

        // Mint tokens to the test account
        mockToken.mint(address(this), topUpAmount);

        // Approve the blueprint contract to spend tokens
        mockToken.approve(address(blueprint), topUpAmount);

        // expect topupOther event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.UserTopUpOther(
            address(this), workerAddress, blueprint.feeCollectionWalletAddress(), address(mockToken), topUpAmount
        );

        // Call the userTopUpOther function
        blueprint.userTopUpOther(workerAddress, address(mockToken), topUpAmount);
        // Verify the top-up amount
        uint256 otherBalance = blueprint.userTopUpMp(workerAddress, address(mockToken));
        assertEq(otherBalance, topUpAmount, "User top-up amount is incorrect");
        // Verify the token transfer
        uint256 blueprintBalance = mockToken.balanceOf(blueprint.feeCollectionWalletAddress());
        assertEq(blueprintBalance, topUpAmount, "Blueprint fee collection wallet balance is incorrect");

        // verify user balance after top up
        uint256 balance = mockToken.balanceOf(address(this));
        assertEq(balance, 0, "sender does not have the correct token balance after top up");

        // Add the payment address for eth
        blueprint.addPaymentAddress(address(0));
        topUpAmount = 1 ether;
        // expect topupOther event
        vm.expectEmit(true, true, true, true);
        emit BlueprintCore.UserTopUpOther(
            address(this), workerAddress, blueprint.feeCollectionWalletAddress(), address(0), topUpAmount
        );

        // Call the userTopUpOther function with native token
        blueprint.userTopUpOther{value: topUpAmount}(workerAddress, address(0), topUpAmount);
        // Verify the native token transfer
        uint256 blueprintEthBalance = blueprint.feeCollectionWalletAddress().balance;
        assertEq(blueprintEthBalance, topUpAmount, "Blueprint fee collection wallet balance is incorrect");
        // Verify the top-up amount
        otherBalance = blueprint.userTopUpMp(workerAddress, address(0));
        assertEq(otherBalance, topUpAmount, "User top-up amount is incorrect");
    }

    function test_Revert_userTopUp() public {
        uint256 topUpAmount = 100 * 10 ** 18;

        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));

        // Mint tokens to the test account
        mockToken.mint(address(this), topUpAmount);

        // check user topUp balance
        uint256 userBalance = blueprint.userTopUpMp(address(this), address(mockToken));
        assertEq(userBalance, 0, "User top-up amount is incorrect");

        // not approve blueprint to spend token
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        // Call the userTopUp function
        blueprint.userTopUp(address(mockToken), topUpAmount);

        // check user topUp balance
        userBalance = blueprint.userTopUpMp(address(this), address(mockToken));
        assertEq(userBalance, 0, "User top-up amount is incorrect");
    }

    function test_creditReward() public {
        uint256 rewardAmount = 100 * 10 ** 18;

        // Add the payment address
        blueprint.addPaymentAddress(address(mockToken));

        // Mint tokens to the test account
        mockToken.mint(address(this), rewardAmount);

        // Approve the blueprint contract to spend tokens
        mockToken.approve(address(blueprint), rewardAmount);

        // Expect the CreditReward event
        vm.expectEmit(true, true, true, true);
        emit Blueprint.CreditReward(address(this), rewardAmount);

        // Call the creditReward function
        blueprint.creditReward(address(this), rewardAmount);

        // Verify the token transfer, not doing any transfer to the user, so balance should be zero
        uint256 blueprintBalance = mockToken.balanceOf(blueprint.feeCollectionWalletAddress());
        assertEq(blueprintBalance, 0, "Blueprint fee collection wallet balance is incorrect");

        //admin user does not pay anything for credit reward
        uint256 balance = mockToken.balanceOf(address(this));
        assertEq(balance, rewardAmount, "sender does not have the correct token balance after credit reward");
    }

    function test_addPaymentAddress() public {
        address paymentAddress = address(mockToken);

        // Expect the PaymentAddressAdded event
        vm.expectEmit(true, true, true, true);
        emit Blueprint.PaymentAddressAdded(paymentAddress);

        // Call the addPaymentAddress function
        blueprint.addPaymentAddress(paymentAddress);

        // Verify the payment address is added
        bool isPaymentAddressEnabled = blueprint.paymentAddressEnableMp(paymentAddress);
        assertTrue(isPaymentAddressEnabled, "Payment address should be enabled");

        // Cannot add again
        vm.expectRevert("Payment address was already added");
        blueprint.addPaymentAddress(paymentAddress);

        // Remove and then you can add again, but no duplicates
        blueprint.removePaymentAddress(paymentAddress);
        isPaymentAddressEnabled = blueprint.paymentAddressEnableMp(paymentAddress);
        assertFalse(isPaymentAddressEnabled, "Payment address should be disabled");

        blueprint.addPaymentAddress(paymentAddress);
        isPaymentAddressEnabled = blueprint.paymentAddressEnableMp(paymentAddress);
        assertTrue(isPaymentAddressEnabled, "Payment address should be enabled");

        // Verify the payment address is in the list
        address[] memory paymentAddresses = blueprint.getPaymentAddresses();
        uint256 found = 0;
        for (uint256 i = 0; i < paymentAddresses.length; i++) {
            if (paymentAddresses[i] == paymentAddress) {
                found += 1;
            }
        }

        assertTrue(found == 1, "Payment address should be in the list, exactly once");
    }
}
