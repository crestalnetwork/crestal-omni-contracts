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
        IERC721 nftToken = IERC721(nftTokenAddress);
        return nftToken.ownerOf(nftId) == userAddress;
    }

    function payWithERC20(address erc20TokenAddress, uint256 amount, address userAddress, address toAddress) external {
        IERC20 token = IERC20(erc20TokenAddress);

        // check if user has enough balance
        require(token.balanceOf(userAddress) >= amount, "Insufficient balance");

        require(token.transferFrom(userAddress, toAddress, amount), "ERC20 transfer failed");
    }
}
