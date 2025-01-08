// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

contract EIP712 {
    string public constant SIGNING_DOMAIN = "app.crestal.network";
    bytes32 public constant PROPOSAL_REQUEST_TYPEHASH =
        keccak256("ProposalRequest(bytes32 projectId,string base64RecParam,string serverURL)");
    bytes32 public constant DEPLOYMENT_REQUEST_TYPEHASH =
        keccak256("DeploymentRequest(bytes32 projectId,string base64RecParam,string serverURL)");

    bytes32 private domainSeparator;

    constructor(address blueprintAddress, string memory blueprintVersion) {
        // Initialize the domain separator
        domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(SIGNING_DOMAIN)),
                keccak256(bytes(blueprintVersion)),
                block.chainid,
                blueprintAddress
            )
        );
    }

    function getBlueprintDomainSeparator() public view returns (bytes32) {
        return domainSeparator;
    }

    function getRequestProposalDigest(bytes32 projectId, string calldata base64RecParam, string calldata serverURL)
        public
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                PROPOSAL_REQUEST_TYPEHASH, projectId, keccak256(bytes(base64RecParam)), keccak256(bytes(serverURL))
            )
        );

        // Hash the data with the domain separator
        bytes32 digest = calculateEIP712Digest(structHash);

        return digest;
    }

    function getRequestDeploymentDigest(bytes32 projectId, string calldata base64RecParam, string calldata serverURL)
        public
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                DEPLOYMENT_REQUEST_TYPEHASH, projectId, keccak256(bytes(base64RecParam)), keccak256(bytes(serverURL))
            )
        );

        // Hash the data with the domain separator
        bytes32 digest = calculateEIP712Digest(structHash);

        return digest;
    }

    function getDomainSeparator(address contractAddress, string calldata version) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(SIGNING_DOMAIN)),
                keccak256(bytes(version)),
                block.chainid,
                contractAddress
            )
        );
    }

    // Helper function to hash the EIP-712 structured data
    function calculateEIP712Digest(bytes32 structHash) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function getSignerAddress(bytes32 hash, bytes memory signature) public pure returns (address) {
        address signerAddr = recover(hash, signature);
        // Require that the signer is not the zero address (or any other custom validation)
        require(signerAddr != address(0), "Invalid signature");
        return signerAddr;
    }

    // EIP-712 signature recovery function
    function recover(bytes32 hash, bytes memory signature) public pure returns (address) {
        // The signature should be 65 bytes (r, s, v)
        require(signature.length == 65, "invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // Extract r, s, v from the signature
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Return the address recovered from the signature
        return ecrecover(hash, v, r, s);
    }
}
