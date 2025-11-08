// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { NFT } from "../../src/NFT.sol";
import { Gov } from "../../src/Gov.sol";

/**
 * @title ProofHelper
 * @notice Library for generating cross-chain operation proofs in tests
 * @dev Centralizes proof generation logic to avoid duplication across tests
 */
library ProofHelper {
    /*//////////////////////////////////////////////////////////////
                        NFT PROOF GENERATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a proof for cross-chain NFT minting
     * @param contractAddress Address of the NFT contract on target chain
     * @param tokenId ID of the token to mint
     * @param to Address to mint the token to
     * @param uri Token metadata URI
     * @return proof Encoded proof data
     */
    function generateMintProof(
        address contractAddress,
        uint256 tokenId,
        address to,
        string memory uri
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes32 message = keccak256(abi.encodePacked(contractAddress, uint8(NFT.OperationType.MINT), tokenId, to, uri));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(tokenId, to, uri, digest);
    }

    /**
     * @notice Generates a proof for cross-chain NFT burning
     * @param contractAddress Address of the NFT contract on target chain
     * @param tokenId ID of the token to burn
     * @return proof Encoded proof data
     */
    function generateBurnProof(address contractAddress, uint256 tokenId) internal pure returns (bytes memory) {
        bytes32 message = keccak256(abi.encodePacked(contractAddress, uint8(NFT.OperationType.BURN), tokenId));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(tokenId, digest);
    }

    /**
     * @notice Generates a proof for cross-chain metadata update
     * @param contractAddress Address of the NFT contract on target chain
     * @param tokenId ID of the token to update
     * @param uri New metadata URI
     * @return proof Encoded proof data
     */
    function generateMetadataProof(
        address contractAddress,
        uint256 tokenId,
        string memory uri
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes32 message =
            keccak256(abi.encodePacked(contractAddress, uint8(NFT.OperationType.SET_METADATA), tokenId, uri));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(tokenId, uri, digest);
    }

    /**
     * @notice Generates a proof for cross-chain delegation
     * @param contractAddress Address of the NFT contract on target chain
     * @param delegator Address delegating voting power
     * @param delegatee Address receiving the delegation
     * @return proof Encoded proof data
     */
    function generateDelegationProof(
        address contractAddress,
        address delegator,
        address delegatee
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes32 message = keccak256(
            abi.encodePacked(contractAddress, uint8(NFT.OperationType.SET_DELEGATION), delegator, delegatee)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(delegator, delegatee, digest);
    }

    /*//////////////////////////////////////////////////////////////
                    GOVERNANCE PROOF GENERATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a proof for cross-chain manifesto update
     * @param contractAddress Address of the Gov contract on target chain
     * @param manifesto New manifesto CID
     * @return proof Encoded proof data
     */
    function generateManifestoProof(
        address contractAddress,
        string memory manifesto
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes32 message =
            keccak256(abi.encodePacked(contractAddress, uint8(Gov.OperationType.SET_MANIFESTO), manifesto));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(manifesto, digest);
    }

    /**
     * @notice Generates a proof for cross-chain governance parameter update
     * @param contractAddress Address of the Gov contract on target chain
     * @param opType Type of parameter update operation
     * @param valueBytes Encoded parameter value
     * @return proof Encoded proof data
     */
    function generateParameterProof(
        address contractAddress,
        Gov.OperationType opType,
        bytes memory valueBytes
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes32 message = keccak256(abi.encodePacked(contractAddress, uint8(opType), valueBytes));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(opType, valueBytes, digest);
    }

    /**
     * @notice Generates a proof for updating voting delay
     * @param contractAddress Address of the Gov contract on target chain
     * @param newDelay New voting delay value
     * @return proof Encoded proof data
     */
    function generateVotingDelayProof(address contractAddress, uint48 newDelay) internal pure returns (bytes memory) {
        bytes memory valueBytes = abi.encodePacked(newDelay);
        return generateParameterProof(contractAddress, Gov.OperationType.UPDATE_VOTING_DELAY, valueBytes);
    }

    /**
     * @notice Generates a proof for updating voting period
     * @param contractAddress Address of the Gov contract on target chain
     * @param newPeriod New voting period value
     * @return proof Encoded proof data
     */
    function generateVotingPeriodProof(address contractAddress, uint32 newPeriod) internal pure returns (bytes memory) {
        bytes memory valueBytes = abi.encodePacked(newPeriod);
        return generateParameterProof(contractAddress, Gov.OperationType.UPDATE_VOTING_PERIOD, valueBytes);
    }

    /**
     * @notice Generates a proof for updating proposal threshold
     * @param contractAddress Address of the Gov contract on target chain
     * @param newThreshold New proposal threshold value
     * @return proof Encoded proof data
     */
    function generateProposalThresholdProof(
        address contractAddress,
        uint256 newThreshold
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory valueBytes = abi.encodePacked(newThreshold);
        return generateParameterProof(contractAddress, Gov.OperationType.UPDATE_PROPOSAL_THRESHOLD, valueBytes);
    }

    /**
     * @notice Generates a proof for updating quorum numerator
     * @param contractAddress Address of the Gov contract on target chain
     * @param newQuorum New quorum numerator value
     * @return proof Encoded proof data
     */
    function generateQuorumProof(address contractAddress, uint256 newQuorum) internal pure returns (bytes memory) {
        bytes memory valueBytes = abi.encodePacked(newQuorum);
        return generateParameterProof(contractAddress, Gov.OperationType.UPDATE_QUORUM, valueBytes);
    }

    /*//////////////////////////////////////////////////////////////
                    INVALID PROOF GENERATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates an invalid mint proof (wrong digest)
     * @dev Useful for testing proof validation
     * @param contractAddress Address of the NFT contract
     * @param tokenId Token ID
     * @param to Recipient address
     * @param uri Token URI
     * @return proof Invalid proof data
     */
    function generateInvalidMintProof(
        address contractAddress,
        uint256 tokenId,
        address to,
        string memory uri
    )
        internal
        pure
        returns (bytes memory)
    {
        // Generate a valid message but corrupt the digest
        bytes32 message = keccak256(abi.encodePacked(contractAddress, uint8(NFT.OperationType.MINT), tokenId, to, uri));
        bytes32 invalidDigest = keccak256(abi.encodePacked(message, "corrupted"));

        return abi.encode(tokenId, to, uri, invalidDigest);
    }

    /**
     * @notice Generates an invalid manifesto proof (wrong contract address)
     * @param manifesto Manifesto CID
     * @return proof Invalid proof data
     */
    function generateInvalidManifestoProof(
        address,
        /* contractAddress */
        string memory manifesto
    )
        internal
        pure
        returns (bytes memory)
    {
        // Use wrong contract address in message
        bytes32 message =
            keccak256(abi.encodePacked(address(0xdead), uint8(Gov.OperationType.SET_MANIFESTO), manifesto));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(manifesto, digest);
    }
}
