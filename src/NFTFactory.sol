// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.29 <0.9.0;

import { NFT } from "./NFT.sol";

/**
 * @title NFTFactory
 * @author W3HC
 * @notice Factory for NFT deployment
 * @custom:security-contact julien@strat.cc
 */
contract NFTFactory {
    /// @notice Address of the GovFactory that will be set as owner of deployed NFT
    address public immutable GOV_FACTORY;

    /// @notice Emitted when a new NFT contract is deployed
    event NFTDeployed(address indexed nft);

    /**
     * @notice Initializes the NFTFactory with the associated GovFactory
     * @param _govFactory Address of the GovFactory that will own deployed NFTs
     */
    constructor(address _govFactory) {
        GOV_FACTORY = _govFactory;
    }

    /**
     * @notice Deploys a new NFT contract and transfers ownership to the GovFactory
     * @param homeChainId The chain ID that will be considered the home chain for the DAO
     * @param salt A unique salt for deterministic deployment
     * @param initialMembers Array of addresses to receive initial membership NFTs
     * @param name Name of the DAO
     * @param nftSymbol Symbol for the membership NFT
     * @param nftURI URI for the NFT metadata
     * @return Address of the deployed NFT contract
     */
    function deployNFT(
        uint256 homeChainId,
        bytes32 salt,
        address[] calldata initialMembers,
        string calldata name,
        string calldata nftSymbol,
        string calldata nftURI
    )
        external
        returns (address)
    {
        bytes32 nftSalt = keccak256(abi.encodePacked(salt, "NFT"));

        address nftAddress =
            address(new NFT{ salt: nftSalt }(homeChainId, address(this), initialMembers, nftURI, name, nftSymbol));

        NFT(nftAddress).transferOwnership(GOV_FACTORY);

        emit NFTDeployed(nftAddress);
        return nftAddress;
    }
}
