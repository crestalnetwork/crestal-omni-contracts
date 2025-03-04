// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract Payment {
    function checkNFTOwnership(address nftTokenAddress, uint256 nftId, address userAddress)
        public
        view
        returns (bool)
    {
        require(nftTokenAddress != address(0), "Invalid NFT token address");
        require(userAddress != address(0), "Invalid user address");

        IERC721 nftToken = IERC721(nftTokenAddress);
        return nftToken.ownerOf(nftId) == userAddress;
    }

    function payWithERC20(address erc20TokenAddress, uint256 amount, address fromAddress, address toAddress) public {
        // check from and to address
        require(fromAddress != address(0), "Invalid from address");
        require(toAddress != address(0), "Invalid to address");
        require(fromAddress != toAddress, "From and to address cannot be the same");
        require(amount > 0, "Amount must be greater than 0");
        require(erc20TokenAddress != address(0), "Invalid ERC20 token address");

        IERC20 token = IERC20(erc20TokenAddress);

        // check if user has enough balance
        require(token.balanceOf(fromAddress) >= amount, "Insufficient balance");

        require(token.transferFrom(fromAddress, toAddress, amount), "ERC20 transfer failed");
    }

    // frontend use directly call token approve function, this function is not needed
    //    function approveERC20(address erc20TokenAddress, uint256 amount, address approvedAddress) public {
    //        require(erc20TokenAddress != address(0), "Invalid ERC20 token address");
    //        require(amount > 0, "Amount must be greater than 0");
    //
    //        IERC20 token = IERC20(erc20TokenAddress);
    //
    //        // check if user has enough balance
    //        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
    //        // approve blueprint contract to help to transfer token
    //        require(token.approve(approvedAddress, amount), "ERC20 approve failed");
    //    }
}
