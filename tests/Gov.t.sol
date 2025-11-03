// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";

contract GovTest is Test {
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

    uint32 public proposalId;

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
    }

    // NFT Core Functionality

    function testInitialNFTDistribution() public view {
        // Check that the initial NFTs were minted correctly
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);

        // Check total supply
        assertEq(nft.totalSupply(), 2);
    }

    function testNonTransferableNFT() public {
        // Try to transfer token and expect revert
        vm.startPrank(alice);

        vm.expectRevert(NFT.NFTNonTransferable.selector);
        nft.transferFrom(alice, francis, 0);

        vm.stopPrank();
    }

    function testDAOMintNFT() public {
        // Gov (DAO) should be able to mint new NFTs
        vm.startPrank(address(gov));

        // Mint a new token to francis
        nft.safeMint(francis, "ipfs://QmNewTokenURI");

        vm.stopPrank();

        // Check the new token was minted correctly
        assertEq(nft.balanceOf(francis), 1);
        assertEq(nft.ownerOf(2), francis);
        assertEq(nft.tokenURI(2), "ipfs://QmNewTokenURI");

        // Check updated total supply
        assertEq(nft.totalSupply(), 3);
    }

    // Delegation Mechanics - Basic Delegation

    function testNFTHolderDelegation() public {
        // Check initial self-delegation
        assertEq(nft.getVotes(alice), 1);

        // alice delegates to bob
        vm.prank(alice);
        nft.delegate(bob);

        // Check votes after delegation (need to advance to next block for delegation to take effect)
        vm.roll(block.number + 1);

        // alice should have 0 votes now
        assertEq(nft.getVotes(alice), 0);

        // bob should have 2 votes now (their own + alice's)
        assertEq(nft.getVotes(bob), 2);
    }

    function testNonNFTHolderDelegation() public {
        // attacker tries to delegate (this should work but have no effect)
        vm.prank(attacker);
        nft.delegate(alice);

        // Advance a block
        vm.roll(block.number + 1);

        // attacker should still have 0 votes
        assertEq(nft.getVotes(attacker), 0);

        // alice should still only have their original vote
        assertEq(nft.getVotes(alice), 1);
    }

    function testDelegationTransfer() public {
        // Initial state
        assertEq(nft.getVotes(alice), 1);
        assertEq(nft.getVotes(bob), 1);
        assertEq(nft.getVotes(francis), 0);

        // alice delegates to bob
        vm.prank(alice);
        nft.delegate(bob);

        // Advance a block
        vm.roll(block.number + 1);

        // Check intermediate state
        assertEq(nft.getVotes(alice), 0);
        assertEq(nft.getVotes(bob), 2);

        // alice now delegates to user3
        vm.prank(alice);
        nft.delegate(francis);

        // Advance a block
        vm.roll(block.number + 1);

        // Final state
        assertEq(nft.getVotes(alice), 0);
        assertEq(nft.getVotes(bob), 1); // Back to just their own vote
        assertEq(nft.getVotes(francis), 1); // Now has alice's vote
    }

    function testNonHolderMultipleDelegations() public {
        // attacker delegates to alice
        vm.prank(attacker);
        nft.delegate(alice);

        // Advance a block
        vm.roll(block.number + 1);

        // Check votes (should be unchanged)
        assertEq(nft.getVotes(alice), 1);
        assertEq(nft.getVotes(attacker), 0);

        // attacker delegates to bob
        vm.prank(attacker);
        nft.delegate(bob);

        // Advance a block
        vm.roll(block.number + 1);

        // Check votes again (should still be unchanged)
        assertEq(nft.getVotes(alice), 1);
        assertEq(nft.getVotes(bob), 1);
        assertEq(nft.getVotes(attacker), 0);
    }

    // Proposal ID Tracking Tests

    function testProposalIdTracking() public {
        // alice delegates to themselves and bob delegates to themselves
        vm.prank(alice);
        nft.delegate(alice);
        vm.prank(bob);
        nft.delegate(bob);

        // Advance block to activate delegation
        vm.roll(block.number + 1);

        // Create a proposal as alice
        proposalTargets = new address[](1);
        proposalValues = new uint256[](1);
        proposalCalldatas = new bytes[](1);
        proposalTargets[0] = address(gov);
        proposalValues[0] = 0;
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", newManifesto);
        proposalDescription = "Update manifesto";

        vm.prank(alice);
        uint256 proposalId1 = gov.propose(proposalTargets, proposalValues, proposalCalldatas, proposalDescription);

        // Check that we can retrieve the proposal ID
        assertEq(gov.proposalIds(0), proposalId1);
    }

    function testMultipleProposalTracking() public {
        // Setup delegation
        vm.prank(alice);
        nft.delegate(alice);
        vm.prank(bob);
        nft.delegate(bob);

        // Advance block
        vm.roll(block.number + 1);

        // Create first proposal
        proposalTargets = new address[](1);
        proposalValues = new uint256[](1);
        proposalCalldatas = new bytes[](1);
        proposalTargets[0] = address(gov);
        proposalValues[0] = 0;
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", "QmFirstProposal");

        vm.prank(alice);
        uint256 proposalId1 = gov.propose(proposalTargets, proposalValues, proposalCalldatas, "First proposal");

        // Create second proposal
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", "QmSecondProposal");

        vm.prank(bob);
        uint256 proposalId2 = gov.propose(proposalTargets, proposalValues, proposalCalldatas, "Second proposal");

        // Create third proposal
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", "QmThirdProposal");

        vm.prank(alice);
        uint256 proposalId3 = gov.propose(proposalTargets, proposalValues, proposalCalldatas, "Third proposal");

        // Check individual proposal IDs
        assertEq(gov.proposalIds(0), proposalId1);
        assertEq(gov.proposalIds(1), proposalId2);
        assertEq(gov.proposalIds(2), proposalId3);
    }
}
