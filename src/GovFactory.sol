// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.29 <0.9.0;

import { Gov } from "./Gov.sol";
import { NFT } from "./NFT.sol";

/**
 * @title GovFactory
 * @author W3HC
 * @notice Factory for Gov deployment
 * @custom:security-contact julien@strat.cc
 */
contract GovFactory {
    event GovDeployed(address indexed gov);

    /**
     * @notice Deploys a new governance contract with deterministic address
     * @dev Uses CREATE2 for consistent addresses across chains
     * @param homeChainId Chain ID of the DAO's home chain
     * @param salt Unique salt for address derivation
     * @param nft Address of the membership NFT contract
     * @param manifestoCid IPFS CID of the DAO's manifesto
     * @param name Name of the DAO
     * @param votingDelay Blocks before voting begins
     * @param votingPeriod Duration of voting in blocks
     * @param proposalThreshold Minimum votes needed to propose
     * @param quorumPercentage Minimum participation percentage
     * @return gov Address of the newly deployed governance contract
     */
    function deployGov(
        uint256 homeChainId,
        bytes32 salt,
        NFT nft,
        string calldata manifestoCid,
        string calldata name,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    )
        external
        returns (address gov)
    {
        bytes32 govSalt = keccak256(abi.encodePacked(salt, "GOV"));
        bytes memory bytecode = abi.encodePacked(
            type(Gov).creationCode,
            abi.encode(homeChainId, nft, manifestoCid, name, votingDelay, votingPeriod, proposalThreshold, quorumPercentage)
        );

        assembly {
            gov := create2(0, add(bytecode, 0x20), mload(bytecode), govSalt)
            if iszero(gov) { revert(0, 0) }
        }

        NFT(nft).transferOwnership(gov);

        emit GovDeployed(gov);
    }
}
