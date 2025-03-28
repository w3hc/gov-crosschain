// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Test, console } from "forge-std/src/Test.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

/**
 * @title CrossChainTest
 * @notice Test file demonstrating cross-chain functionality between Optimism and Arbitrum
 * @dev Simulates two chains using chainId switching and tests both deployments and cross-chain operations
 */
contract CrossChainTest is Test {
    // Chain IDs
    uint256 public constant OPTIMISM_CHAIN_ID = 10;
    uint256 public constant ARBITRUM_CHAIN_ID = 42_161;

    // Contracts on Optimism (home chain)
    Gov public govOptimism;
    NFT public nftOptimism;

    // Contracts on Arbitrum (foreign chain)
    Gov public govArbitrum;
    NFT public nftArbitrum;

    // Test accounts
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Governance parameters
    string public initialManifesto = "QmInitialManifestoCID";
    string public newManifesto = "QmNewManifestoCID";
    uint48 public votingDelay = 1;
    uint32 public votingPeriod = 30;
    uint256 public proposalThreshold = 0;
    uint256 public quorumNumerator = 4;

    // Proposal variables
    uint256 public proposalId;
    address[] public proposalTargets;
    uint256[] public proposalValues;
    bytes[] public proposalCalldatas;
    string public proposalDescription;
    bytes32 public descriptionHash;

    // Cross-chain operation variables
    bytes public manifestoProof;
    bytes public membershipProof;

    function setUp() public {
        // Deploy contracts on Optimism (home chain)
        deployOnOptimism();

        // Deploy contracts on Arbitrum (foreign chain)
        deployOnArbitrum();

        // Setup initial state and test parameters
        setupTestParameters();
    }

    function deployOnOptimism() internal {
        // Set chain to Optimism
        vm.chainId(OPTIMISM_CHAIN_ID);
        console.log("Deploying on Optimism (Home Chain) - Chain ID:", block.chainid);

        vm.startPrank(deployer);

        // Create initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = alice;
        initialMembers[1] = bob;

        // Deploy NFT contract
        nftOptimism =
            new NFT(OPTIMISM_CHAIN_ID, deployer, initialMembers, "ipfs://QmTokenURI", "DAO Membership", "DAOM");
        console.log("Optimism - NFT deployed at:", address(nftOptimism));

        // Deploy governance contract
        govOptimism = new Gov(
            OPTIMISM_CHAIN_ID,
            nftOptimism,
            initialManifesto,
            "Cross-Chain Governance",
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumNumerator
        );
        console.log("Optimism - Gov deployed at:", address(govOptimism));

        // Transfer NFT ownership to governance contract
        nftOptimism.transferOwnership(address(govOptimism));
        console.log("Optimism - NFT ownership transferred to Gov");

        vm.stopPrank();
    }

    function deployOnArbitrum() internal {
        // Set chain to Arbitrum
        vm.chainId(ARBITRUM_CHAIN_ID);
        console.log("Deploying on Arbitrum (Foreign Chain) - Chain ID:", block.chainid);

        vm.startPrank(deployer);

        // Create initial members array - same as on Optimism
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = alice;
        initialMembers[1] = bob;

        // Deploy NFT contract with the same parameters
        nftArbitrum = new NFT(
            OPTIMISM_CHAIN_ID, // Note: Home chain ID is still Optimism
            deployer,
            initialMembers,
            "ipfs://QmTokenURI",
            "DAO Membership",
            "DAOM"
        );
        console.log("Arbitrum - NFT deployed at:", address(nftArbitrum));

        // Deploy governance contract
        govArbitrum = new Gov(
            OPTIMISM_CHAIN_ID, // Note: Home chain ID is still Optimism
            nftArbitrum,
            initialManifesto,
            "Cross-Chain Governance",
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumNumerator
        );
        console.log("Arbitrum - Gov deployed at:", address(govArbitrum));

        // Transfer NFT ownership to governance contract
        nftArbitrum.transferOwnership(address(govArbitrum));
        console.log("Arbitrum - NFT ownership transferred to Gov");

        vm.stopPrank();
    }

    function setupTestParameters() internal {
        // Set up a proposal to update the manifesto
        proposalTargets = new address[](1);
        proposalTargets[0] = address(govOptimism);

        proposalValues = new uint256[](1);
        proposalValues[0] = 0;

        proposalCalldatas = new bytes[](1);
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", newManifesto);

        proposalDescription = "Proposal #1: Update DAO manifesto to new version";
        descriptionHash = keccak256(bytes(proposalDescription));
    }

    function testDeploymentStateConsistency() public {
        // Test Optimism deployment
        vm.chainId(OPTIMISM_CHAIN_ID);
        assertEq(nftOptimism.totalSupply(), 2);
        assertEq(nftOptimism.ownerOf(0), alice);
        assertEq(nftOptimism.ownerOf(1), bob);
        assertEq(nftOptimism.owner(), address(govOptimism));
        assertEq(govOptimism.manifesto(), initialManifesto);

        // Test Arbitrum deployment
        vm.chainId(ARBITRUM_CHAIN_ID);
        assertEq(nftArbitrum.totalSupply(), 2);
        assertEq(nftArbitrum.ownerOf(0), alice);
        assertEq(nftArbitrum.ownerOf(1), bob);
        assertEq(nftArbitrum.owner(), address(govArbitrum));
        assertEq(govArbitrum.manifesto(), initialManifesto);

        console.log("Initial state consistency verified between chains");
    }

    function testCrossChainManifestoUpdate() public {
        // STEP 1: Directly update manifesto on Optimism through governance contract
        vm.chainId(OPTIMISM_CHAIN_ID);
        console.log("--- OPTIMISM (Home Chain) OPERATIONS ---");

        // Set up governance for simplicity
        vm.prank(alice);
        nftOptimism.delegate(alice);

        vm.prank(bob);
        nftOptimism.delegate(bob);

        vm.roll(block.number + 1); // Advance to next block

        // For test simplicity, we'll skip the proposal process and directly update the manifesto
        // This simulates a proposal that has already passed governance
        vm.prank(address(govOptimism));
        govOptimism.setManifesto(newManifesto);
        console.log("Manifesto updated on Optimism via governance");

        // Verify manifesto was updated on Optimism
        assertEq(govOptimism.manifesto(), newManifesto);
        console.log("Manifesto on Optimism is now:", govOptimism.manifesto());

        // STEP 2: Generate proof for Arbitrum - manually for testing
        // Create proof message and digest using the target contract address
        bytes32 message = keccak256(
            abi.encodePacked(
                address(govArbitrum), // Important: use target contract address
                uint8(Gov.OperationType.SET_MANIFESTO),
                newManifesto
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        manifestoProof = abi.encode(newManifesto, digest);
        console.log("Manifesto proof generated manually for testing");

        // STEP 3: Submit proof to Arbitrum
        vm.chainId(ARBITRUM_CHAIN_ID);
        console.log("--- ARBITRUM (Foreign Chain) OPERATIONS ---");

        // Initial state on Arbitrum (still old manifesto)
        assertEq(govArbitrum.manifesto(), initialManifesto);
        console.log("Initial Arbitrum manifesto:", govArbitrum.manifesto());

        // Submit proof to Arbitrum
        vm.prank(alice);
        govArbitrum.claimManifestoUpdate(manifestoProof);
        console.log("Manifesto update claimed on Arbitrum");

        // Verify manifesto was updated on Arbitrum
        assertEq(govArbitrum.manifesto(), newManifesto);
        console.log("Manifesto updated on Arbitrum to:", govArbitrum.manifesto());

        // Verify both chains have the same manifesto
        assertEq(govOptimism.manifesto(), govArbitrum.manifesto());
        console.log("Manifesto synchronized across chains");
    }

    function testCrossChainMembership() public {
        // STEP 1: Mint a new membership on Optimism
        vm.chainId(OPTIMISM_CHAIN_ID);
        console.log("--- OPTIMISM (Home Chain) OPERATIONS ---");

        // Mint new NFT to charlie through governance
        vm.prank(address(govOptimism));
        nftOptimism.safeMint(charlie, "ipfs://QmCharlieTokenURI");
        console.log("New membership minted to Charlie on Optimism");

        // Verify charlie has membership on Optimism
        assertEq(nftOptimism.balanceOf(charlie), 1);

        // Find Charlie's token ID
        uint256 charlieTokenId = type(uint256).max;
        for (uint256 i = 0; i < nftOptimism.totalSupply(); i++) {
            if (nftOptimism.ownerOf(i) == charlie) {
                charlieTokenId = i;
                break;
            }
        }
        require(charlieTokenId != type(uint256).max, "Charlie's token not found");
        console.log("Charlie's token ID:", charlieTokenId);

        // STEP 2: Generate proof for membership claim on Arbitrum
        // Since the contracts are actually different on the two chains, we need to simulate
        // what would happen in a real cross-chain scenario

        // First, create a simplified proof manually for testing
        bytes32 message = keccak256(
            abi.encodePacked(
                address(nftArbitrum), // Important: use the target contract address
                uint8(0), // MINT operation type
                charlieTokenId,
                charlie,
                "ipfs://QmCharlieTokenURI"
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        // Pack the proof in the expected format
        membershipProof = abi.encode(charlieTokenId, charlie, "ipfs://QmCharlieTokenURI", digest);
        console.log("Membership proof generated (manually for testing)");

        // STEP 3: Claim membership on Arbitrum
        vm.chainId(ARBITRUM_CHAIN_ID);
        console.log("--- ARBITRUM (Foreign Chain) OPERATIONS ---");

        // Initial state on Arbitrum (charlie has no membership)
        assertEq(nftArbitrum.balanceOf(charlie), 0);
        console.log("Initial Charlie's balance on Arbitrum:", nftArbitrum.balanceOf(charlie));

        // Submit claim to Arbitrum
        vm.prank(charlie);
        nftArbitrum.claimMint(membershipProof);
        console.log("Membership claimed on Arbitrum");

        // Verify charlie now has membership on Arbitrum
        assertEq(nftArbitrum.balanceOf(charlie), 1);
        assertEq(nftArbitrum.ownerOf(charlieTokenId), charlie);
        console.log("Charlie now has membership on Arbitrum with token ID:", charlieTokenId);

        // Verify token URI is the same across chains
        assertEq(nftOptimism.tokenURI(charlieTokenId), nftArbitrum.tokenURI(charlieTokenId));
        console.log("Membership synchronized across chains");
    }

    function testCrossChainParameterSync() public {
        // STEP 1: Directly update voting delay on Optimism (simulating governance)
        vm.chainId(OPTIMISM_CHAIN_ID);
        console.log("--- OPTIMISM (Home Chain) OPERATIONS ---");

        uint48 newVotingDelay = 200; // New voting delay value

        // For test simplicity, we'll directly update the parameter
        // This simulates a proposal that has already passed governance
        vm.prank(address(govOptimism));
        govOptimism.setVotingDelay(newVotingDelay);

        // Verify voting delay was updated on Optimism
        assertEq(govOptimism.votingDelay(), newVotingDelay);
        console.log("Voting delay updated on Optimism to:", govOptimism.votingDelay());

        // STEP 2: Generate proof for Arbitrum
        // Similar to the membership test, we'll create a manual proof
        // Since the contracts are different instances on different chains

        // Convert the value to bytes
        bytes memory valueBytes = abi.encodePacked(newVotingDelay);

        // Create proof message and digest
        bytes32 message = keccak256(
            abi.encodePacked(
                address(govArbitrum), // Important: use target contract address
                uint8(Gov.OperationType.UPDATE_VOTING_DELAY),
                valueBytes
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        // Pack the proof in expected format
        bytes memory paramProof = abi.encode(Gov.OperationType.UPDATE_VOTING_DELAY, valueBytes, digest);
        console.log("Parameter proof generated (manually for testing)");

        // STEP 3: Submit proof to Arbitrum
        vm.chainId(ARBITRUM_CHAIN_ID);
        console.log("--- ARBITRUM (Foreign Chain) OPERATIONS ---");

        // Initial state on Arbitrum
        assertEq(govArbitrum.votingDelay(), votingDelay);
        console.log("Initial Arbitrum voting delay:", govArbitrum.votingDelay());

        // Submit proof to Arbitrum
        vm.prank(alice);
        govArbitrum.claimParameterUpdate(paramProof);
        console.log("Parameter update claimed on Arbitrum");

        // Verify parameter was updated on Arbitrum
        assertEq(govArbitrum.votingDelay(), newVotingDelay);
        console.log("Voting delay updated on Arbitrum to:", govArbitrum.votingDelay());

        // Verify both chains have the same parameter
        vm.chainId(OPTIMISM_CHAIN_ID);
        uint256 optimismDelay = govOptimism.votingDelay();

        vm.chainId(ARBITRUM_CHAIN_ID);
        uint256 arbitrumDelay = govArbitrum.votingDelay();

        assertEq(optimismDelay, arbitrumDelay);
        console.log("Voting delay synchronized across chains:", optimismDelay);
    }
}
