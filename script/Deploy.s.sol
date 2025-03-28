// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28 <0.9.0;

import { console } from "forge-std/src/Test.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";
import { BaseScript } from "./Base.s.sol";

/// @dev Script to deploy the cross-chain governance system
contract Deploy is BaseScript {
    function run() public broadcast returns (Gov gov, NFT nft) {
        // Get the current chain ID
        uint256 currentChainId = block.chainid;
        console.log("Deploying to chain ID:", currentChainId);

        // Home chain is Optimism (chain ID 10)
        uint256 homeChainId = 10;

        // Create initial members array (use your desired initial members)
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // First default anvil address
        initialMembers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Second default anvil address

        // Deploy the NFT contract first with broadcaster as the owner
        console.log("Deploying NFT contract...");
        console.log("Deploying from address:", broadcaster);
        nft = new NFT(homeChainId, broadcaster, initialMembers, "ipfs://QmTokenURI", "DAO Membership", "DAOM");
        console.log("NFT deployed at:", address(nft));
        console.log("NFT owner:", nft.owner());

        // Deploy the governance contract
        console.log("Deploying Gov contract...");
        gov = new Gov(
            homeChainId,
            nft,
            "QmInitialManifestoCID",
            "Cross-Chain Governance",
            100, // voting delay (blocks)
            1000, // voting period (blocks)
            0, // proposal threshold
            4 // quorum percentage (4%)
        );
        console.log("Gov deployed at:", address(gov));

        // Transfer NFT ownership to governance contract
        console.log("Transferring NFT ownership to Gov contract...");
        console.log("Current NFT owner:", nft.owner());
        nft.transferOwnership(address(gov));
        console.log("New NFT owner:", nft.owner());
        console.log("Deployment complete!");
    }
}
