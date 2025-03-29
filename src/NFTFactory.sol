// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { NFT } from "./NFT.sol";

/**
 * @title NFTFactory
 * @author Web3 Hackers Collective
 * @notice Factory for NFT deployment
 * @custom:security-contact julien@strat.cc
 */
contract NFTFactory {
    event NFTDeployed(address indexed nft);

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
            address(new NFT{ salt: nftSalt }(homeChainId, msg.sender, initialMembers, nftURI, name, nftSymbol));

        emit NFTDeployed(nftAddress);
        return nftAddress;
    }
}
