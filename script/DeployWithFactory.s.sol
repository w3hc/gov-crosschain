// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28 <0.9.0;

import { console } from "forge-std/src/Test.sol";
import { GovFactory } from "../src/GovFactory.sol";
import { BaseScript } from "./Base.s.sol";

/// @dev Script to deploy the cross-chain governance system using the factory with CREATE2
contract DeployWithFactory is BaseScript {
    // Standard salt for deterministic factory deployment
    bytes32 public constant FACTORY_SALT = bytes32(uint256(0x1234)); // You can customize this

    // Standard salt for DAO deployments
    bytes32 public constant DAO_SALT = bytes32(uint256(0x5678)); // You can customize this

    function run() public broadcast returns (GovFactory factory) {
        // Get the current chain ID
        uint256 currentChainId = block.chainid;
        console.log("Deploying Factory to chain ID:", currentChainId);

        // Home chain is Optimism (chain ID 10)
        uint256 homeChainId = 10;

        // Initial members array - must be the same across all chains for deterministic addresses
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // First default anvil address
        initialMembers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Second default anvil address

        // DAO parameters - must be the same across all chains for deterministic addresses
        string memory manifestoCid = "QmInitialManifestoCID";
        string memory name = "Cross-Chain Governance";
        string memory nftSymbol = "DAOM";
        string memory nftURI = "ipfs://QmTokenURI";
        uint48 votingDelay = 100;
        uint32 votingPeriod = 1000;
        uint256 proposalThreshold = 0;
        uint256 quorumPercentage = 4;

        // Deploy the factory contract
        factory = new GovFactory(homeChainId, DAO_SALT);
        console.log("Factory deployed at:", address(factory));

        // Pre-compute NFT and Gov addresses
        (address expectedNft, address expectedGov) = factory.computeDeploymentAddresses(
            initialMembers,
            manifestoCid,
            name,
            nftSymbol,
            nftURI,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercentage
        );

        console.log("Expected NFT address:", expectedNft);
        console.log("Expected Gov address:", expectedGov);

        // Deploy the DAO through the factory
        console.log("Deploying the DAO through the factory...");
        (address nft, address gov) = factory.deployDAO(
            initialMembers,
            manifestoCid,
            name,
            nftSymbol,
            nftURI,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercentage
        );

        console.log("NFT deployed at:", nft);
        console.log("Gov deployed at:", gov);

        // Verify the addresses match the expected addresses
        require(nft == expectedNft, "NFT address mismatch");
        require(gov == expectedGov, "Gov address mismatch");

        console.log("Deployment verification successful!");
        console.log("Deployment complete!");
    }
}
