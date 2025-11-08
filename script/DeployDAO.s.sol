// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { NFTFactory } from "../src/NFTFactory.sol";
import { GovFactory } from "../src/GovFactory.sol";
import { NFT } from "../src/NFT.sol";

/**
 * @title DeployDAO
 * @notice Deploys DAO contracts (NFT and Gov) using factories
 * @dev This script uses the same factory addresses and salt across chains
 *      to ensure deterministic deployment addresses for cross-chain functionality
 */
contract DeployDAO is Script {
    // Factory addresses (same on all chains after using Safe Singleton Factory)
    address public constant GOV_FACTORY_ADDRESS = 0x103a8C4f1f6E42E916e87Ca1d200FfA4b51a68Bd;
    address public constant NFT_FACTORY_ADDRESS = 0xB1781E702762C050F0d4D3d70c463f8d146c5d56;

    // Salt for CREATE2 deployment
    bytes32 public constant SALT = bytes32(uint256(0x5678));

    // Home chain ID for the DAO
    uint256 public constant HOME_CHAIN_ID = 10;

    // Use Anvil's default private key for Alice
    uint256 private constant ALICE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct DAOParams {
        string manifestoCid;
        string name;
        string nftSymbol;
        string nftURI;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumPercentage;
    }

    function run() public returns (address nftAddress, address govAddress) {
        console2.log("Deploying DAO on chain ID:", block.chainid);
        console2.log("Using HOME_CHAIN_ID:", HOME_CHAIN_ID);
        console2.log("Using GovFactory at:", GOV_FACTORY_ADDRESS);
        console2.log("Using NFTFactory at:", NFT_FACTORY_ADDRESS);

        // Initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = vm.addr(ALICE_KEY); // Alice - 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        initialMembers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Bob - Second default anvil address

        // DAO parameters
        DAOParams memory params = DAOParams({
            manifestoCid: "QmInitialManifestoCID",
            name: "Our Cross-Chain DAO",
            nftSymbol: "MEMBER",
            nftURI: "ipfs://QmTokenURI",
            votingDelay: 0,
            votingPeriod: 30,
            proposalThreshold: 0,
            quorumPercentage: 4
        });

        // Start broadcasting transactions with the hardcoded private key
        vm.startBroadcast(ALICE_KEY);

        // Deploy NFT with deterministic address
        console2.log("Deploying NFT...");
        nftAddress = NFTFactory(NFT_FACTORY_ADDRESS)
            .deployNFT(HOME_CHAIN_ID, SALT, initialMembers, params.name, params.nftSymbol, params.nftURI);
        console2.log("NFT deployed at:", nftAddress);
        console2.log("NFT owner is now:", NFT(nftAddress).owner());

        // Deploy Gov with deterministic address
        console2.log("Deploying Gov...");
        govAddress = GovFactory(GOV_FACTORY_ADDRESS)
            .deployGov(
                HOME_CHAIN_ID,
                SALT,
                NFT(nftAddress),
                params.manifestoCid,
                params.name,
                params.votingDelay,
                params.votingPeriod,
                params.proposalThreshold,
                params.quorumPercentage
            );
        console2.log("Gov deployed at:", govAddress);

        // Verify Gov is the owner of NFT
        console2.log("Verifying NFT ownership...");
        require(NFT(nftAddress).owner() == govAddress, "Gov is not the owner of NFT");
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
