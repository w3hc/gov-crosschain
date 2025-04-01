// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { NFTFactory } from "../src/NFTFactory.sol";
import { GovFactory } from "../src/GovFactory.sol";
import { NFT } from "../src/NFT.sol";
import { Gov } from "../src/Gov.sol";

/**
 * @title DeployDAO
 * @notice Deploys DAO contracts (NFT and Gov) using factories
 * @dev This script uses the same factory addresses and salt across chains
 *      to ensure deterministic deployment addresses for cross-chain functionality
 */
contract DeployDAO is Script {
    // Factory addresses (same on all chains after using Safe Singleton Factory)
    address public constant GOV_FACTORY_ADDRESS = 0x1E319F2b9867f688f13Ae289f483608DA2d4b51b;
    address public constant NFT_FACTORY_ADDRESS = 0x6363e1D1075D001857D213641bceF6605E3400dd;

    // Salt for CREATE2 deployment
    bytes32 public constant SALT = bytes32(uint256(0x5678));

    // Home chain ID for the DAO
    uint256 public constant HOME_CHAIN_ID = 10;

    // Use Anvil's default private key for Alice
    uint256 private constant ALICE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public returns (address nftAddress, address govAddress) {
        uint256 currentChainId = block.chainid;

        console2.log("Deploying DAO on chain ID:", currentChainId);
        console2.log("Using HOME_CHAIN_ID:", HOME_CHAIN_ID);
        console2.log("Using GovFactory at:", GOV_FACTORY_ADDRESS);
        console2.log("Using NFTFactory at:", NFT_FACTORY_ADDRESS);

        // Initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // First default anvil address
        initialMembers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Second default anvil address

        // DAO parameters
        string memory manifestoCid = "QmInitialManifestoCID";
        string memory name = "Our Cross-Chain DAO";
        string memory nftSymbol = "MEMBER";
        string memory nftURI = "ipfs://QmTokenURI";
        uint48 votingDelay = 0;
        uint32 votingPeriod = 30;
        uint256 proposalThreshold = 0;
        uint256 quorumPercentage = 4;

        // Get factory instances
        NFTFactory nftFactory = NFTFactory(NFT_FACTORY_ADDRESS);
        GovFactory govFactory = GovFactory(GOV_FACTORY_ADDRESS);

        // Calculate expected addresses
        bytes memory nftCreationCode = abi.encodePacked(
            type(NFT).creationCode,
            abi.encode(HOME_CHAIN_ID, GOV_FACTORY_ADDRESS, initialMembers, nftURI, name, nftSymbol)
        );

        // Start broadcasting transactions with the hardcoded private key
        vm.startBroadcast(ALICE_KEY);

        // Deploy NFT with deterministic address
        console2.log("Deploying NFT...");
        nftAddress = nftFactory.deployNFT(HOME_CHAIN_ID, SALT, initialMembers, name, nftSymbol, nftURI);
        console2.log("NFT deployed at:", nftAddress);
        console2.log("NFT owner is now:", NFT(nftAddress).owner());

        // Deploy Gov with deterministic address
        console2.log("Deploying Gov...");
        govAddress = govFactory.deployGov(
            HOME_CHAIN_ID,
            SALT,
            NFT(nftAddress),
            manifestoCid,
            name,
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumPercentage
        );
        console2.log("Gov deployed at:", govAddress);

        // Verify Gov is the owner of NFT
        console2.log("Verifying NFT ownership...");
        address nftOwner = NFT(nftAddress).owner();
        require(nftOwner == govAddress, "Gov is not the owner of NFT");
        console2.log("Verified: Gov is the owner of NFT");

        // Check initial membership
        console2.log("Checking initial membership...");
        console2.log("Alice (", initialMembers[0], ") is member:", NFT(nftAddress).balanceOf(initialMembers[0]) > 0);
        console2.log("Bob (", initialMembers[1], ") is member:", NFT(nftAddress).balanceOf(initialMembers[1]) > 0);

        vm.stopBroadcast();

        console2.log("Deployment complete!");
        console2.log("Run the same script on the other chain to get the same contract addresses!");
        console2.log("\nNext steps:");
        console2.log("1. Create a proposal on the home chain");
        console2.log("2. Vote on the proposal");
        console2.log("3. Execute the proposal");
        console2.log("4. Generate proof for cross-chain sync");
        console2.log("5. Submit proof to the foreign chain");

        return (nftAddress, govAddress);
    }
}
