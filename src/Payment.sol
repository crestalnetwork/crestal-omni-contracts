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
        require(fromAddress != toAddress, "Cannot transfer to self address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 token = IERC20(erc20TokenAddress);

        // check if user has enough balance
        require(token.balanceOf(fromAddress) >= amount, "Insufficient balance");

        require(token.transferFrom(fromAddress, toAddress, amount), "ERC20 transfer failed");
    }
}
