// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console } from "forge-std/src/Test.sol";
import { NFTFactory } from "../src/NFTFactory.sol";
import { GovFactory } from "../src/GovFactory.sol";
import { NFT } from "../src/NFT.sol";
import { BaseScript } from "./Base.s.sol";

/// @dev Script to deploy the cross-chain governance system using factories with proper order
contract DeployWithFactories is BaseScript {
    bytes32 public constant FACTORY_SALT = bytes32(uint256(0x1234));

    function run() public broadcast returns (address nft, address gov) {
        uint256 currentChainId = block.chainid;
        uint256 homeChainId = 901;

        console.log("Deploying Factories to chain ID:", currentChainId);

        // First deploy the GovFactory
        GovFactory govFactory = new GovFactory();
        console.log("Gov Factory deployed at:", address(govFactory));

        // Then deploy the NFTFactory with GovFactory address
        NFTFactory nftFactory = new NFTFactory(address(govFactory));
        console.log("NFT Factory deployed at:", address(nftFactory));
        console.log("NFT Factory's GovFactory reference:", nftFactory.GOV_FACTORY());

        // Initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        initialMembers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        // DAO parameters
        string memory manifestoCid = "QmInitialManifestoCID";
        string memory name = "Our DAO";
        string memory nftSymbol = "MEMBER";
        string memory nftURI = "ipfs://QmTokenURI";
        uint48 votingDelay = 100;
        uint32 votingPeriod = 1000;
        uint256 proposalThreshold = 0;
        uint256 quorumPercentage = 4;

        // 1. Deploy NFT
        console.log("Deploying NFT...");
        nft = nftFactory.deployNFT(homeChainId, FACTORY_SALT, initialMembers, name, nftSymbol, nftURI);

        console.log("NFT deployed at:", nft);
        console.log("NFT owner is now:", NFT(nft).owner());

        // 2. Deploy Gov
        console.log("Deploying Gov...");
        gov = govFactory.deployGov(
            homeChainId,
            FACTORY_SALT,
            NFT(nft),
            manifestoCid,
            name,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercentage
        );
        console.log("Gov deployed at:", gov);

        // 3. Verify Gov is the owner of NFT
        console.log("Verifying NFT ownership...");
        address nftOwner = NFT(nft).owner();
        require(nftOwner == gov, "Gov is not the owner of NFT");
        console.log("Verified: Gov is the owner of NFT");

        console.log("Deployment complete!");
    }
}
