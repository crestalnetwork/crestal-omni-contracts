// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract Payment {
    IERC721 public nftToken;
    IERC20 public crestalToken;

//    uint256 public erc20Amount;
////    ////    mapping(uint256 => bool) public usedNfts;    mapping(address => mapping(bytes32 => bool)) public paymentStatus;mapping(uint256 => bool) public usedNfts;    mapping(address => mapping(bytes32 => bool)) public paymentStatus;
//
    function __Payment_initialize(address crestalTokenAddress, address nftTokenAddress) public {
        nftToken = IERC721(nftTokenAddress);
        crestalToken = IERC20(crestalTokenAddress);
    }

    event PaymentReceived(address indexed user, uint256 amount, string paymentType);
    event DeploymentRequested(address indexed user, bytes32 projectId);


//    function setErc20Amount(uint256 _erc20Amount) external onlyOwner {
//        erc20Amount = _erc20Amount;
//    }

    function payWithNft(bytes32 projectId, uint256 nftId) external {
        require(nftToken.ownerOf(nftId) == msg.sender, "Not the owner of the NFT");
//        require(!usedNfts[nftId], "NFT already used");
//        usedNfts[nftId] = true;
//        paymentStatus[msg.sender][projectId] = true;
        emit PaymentReceived(msg.sender, nftId, "NFT");

        emit DeploymentRequested(msg.sender, projectId);
    }

    function payWithErc20(bytes32 projectId, string memory base64Proposal, string memory serverURL) external {
        require(crestalToken.transferFrom(msg.sender, address(this), 20), "ERC20 transfer failed");
//        paymentStatus[msg.sender][projectId] = true;
//        emit PaymentReceived(msg.sender, erc20Amount, "ERC20");

        emit DeploymentRequested(msg.sender, projectId);
    }

//    function checkPaymentStatus(address user, bytes32 projectId) external view returns (bool) {
//        return paymentStatus[user][projectId];
//    }

}