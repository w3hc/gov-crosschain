// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Test, console } from "forge-std/src/Test.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

contract ProposalExecutionTest is Test {
    Gov public gov;
    NFT public nft;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public francis = makeAddr("francis");
    address public attacker = makeAddr("attacker");

    uint256 public homeChainId = 10;

    string public initialManifesto = "QmInitialManifestoCID";
    string public newManifesto = "QmNewManifestoCID";

    uint48 public votingDelay = 1;
    uint32 public votingPeriod = 30;
    uint256 public proposalThreshold = 0;
    uint256 public quorumNumerator = 4;

    // Proposal-related variables
    bytes32 public descriptionHash;
    address[] public proposalTargets;
    uint256[] public proposalValues;
    bytes[] public proposalCalldatas;
    string public proposalDescription;

    function setUp() public {
        // Set the home chain for testing
        vm.chainId(homeChainId);

        vm.startPrank(deployer);

        // Create initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = alice;
        initialMembers[1] = bob;

        // Deploy NFT contract first
        nft = new NFT(
            homeChainId,
            deployer,
            initialMembers,
            "ipfs://bafkreicj62l5xu6pk2xx7x7n6b7rpunxb4ehlh7fevyjapid3556smuz4y",
            "Our DAO Membership",
            "MEMBERSHIP"
        );

        vm.stopPrank();

        // Deploy governance contract
        vm.startPrank(deployer);
        gov = new Gov(
            homeChainId, nft, initialManifesto, "Our DAO", votingDelay, votingPeriod, proposalThreshold, quorumNumerator
        );

        // Transfer NFT ownership to governance
        nft.transferOwnership(address(gov));

        vm.stopPrank();

        // Setup a proposal to update the manifesto
        setupManifestoProposal();
    }

    function setupManifestoProposal() internal {
        // Prepare a proposal to update the manifesto
        proposalTargets = new address[](1);
        proposalTargets[0] = address(gov);

        proposalValues = new uint256[](1);
        proposalValues[0] = 0;

        // Prepare the function call to setManifesto
        proposalCalldatas = new bytes[](1);
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", newManifesto);

        // Set proposal description
        proposalDescription = "Proposal #1: Update DAO manifesto to new version";

        // Calculate the description hash (needed for execution)
        descriptionHash = keccak256(bytes(proposalDescription));
    }

    function testSuccessfulProposalExecution() public {
        // First, ensure alice has voting power by self-delegating
        vm.startPrank(alice);
        nft.delegate(alice);
        vm.stopPrank();

        vm.startPrank(bob);
        nft.delegate(bob);
        vm.stopPrank();

        // Verify the voting power
        assertEq(nft.getVotes(alice), 1);
        assertEq(nft.getVotes(bob), 1);

        // Create the proposal
        vm.startPrank(alice);
        uint256 _proposalId = gov.propose(proposalTargets, proposalValues, proposalCalldatas, proposalDescription);
        vm.stopPrank();

        console.log("Proposal created with ID:", _proposalId);

        // Move time forward past the voting delay
        vm.warp(block.timestamp + 2);

        // Verify proposal is now active
        IGovernor.ProposalState state = gov.state(_proposalId);
        assertEq(uint8(state), uint8(IGovernor.ProposalState.Active));
        console.log("Proposal is active");

        // Cast votes
        vm.prank(alice);
        gov.castVote(_proposalId, 1); // 1 = For
        console.log("Alice voted in favor");

        vm.prank(bob);
        gov.castVote(_proposalId, 1); // 1 = For
        console.log("Bob voted in favor");

        // Move time forward past the voting period
        vm.warp(block.timestamp + 51);

        // Verify proposal is now succeeded
        state = gov.state(_proposalId);
        assertEq(uint8(state), uint8(IGovernor.ProposalState.Succeeded));
        console.log("Proposal has succeeded");

        // Execute the proposal
        vm.prank(alice);
        gov.execute(proposalTargets, proposalValues, proposalCalldatas, descriptionHash);
        console.log("Proposal executed");

        // Verify the manifesto was updated
        string memory updatedManifesto = gov.manifesto();
        assertEq(updatedManifesto, newManifesto);
        console.log("Manifesto successfully updated to:", updatedManifesto);
    }
}
