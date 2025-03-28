// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { GovFactory } from "../src/GovFactory.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";

contract GovFactoryTest is Test {
    // Test accounts
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // Factory and deployed contracts
    GovFactory public factory;
    address public nftAddress;
    address public govAddress;

    // Deployment parameters
    uint256 public constant HOME_CHAIN_ID = 10; // Optimism
    bytes32 public constant FACTORY_SALT = bytes32(uint256(0x1234));

    function setUp() public {
        // Deploy the factory contract
        vm.startPrank(deployer);
        factory = new GovFactory(HOME_CHAIN_ID, FACTORY_SALT);
        vm.stopPrank();
    }

    function testFactoryDeployment() public {
        // Verify factory initialization
        assertEq(factory.HOME_CHAIN_ID(), HOME_CHAIN_ID);
        assertEq(factory.owner(), deployer);
        assertEq(factory.DEPLOYMENT_SALT(), FACTORY_SALT);

        // Create initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = alice;
        initialMembers[1] = bob;

        // DAO parameters
        string memory manifestoCid = "QmInitialManifestoCID";
        string memory name = "Test DAO";
        string memory nftSymbol = "DAOMEM";
        string memory nftURI = "ipfs://QmTokenURI";
        uint48 votingDelay = 100;
        uint32 votingPeriod = 1000;
        uint256 proposalThreshold = 0;
        uint256 quorumPercentage = 4;

        // Compute expected addresses before deployment
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

        // Deploy DAO
        vm.startPrank(deployer);
        (nftAddress, govAddress) = factory.deployDAO(
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
        vm.stopPrank();

        // Verify contracts were deployed at expected addresses
        assertEq(nftAddress, expectedNft, "NFT address mismatch");
        assertEq(govAddress, expectedGov, "Gov address mismatch");

        // Verify NFT initial state
        NFT nft = NFT(nftAddress);
        assertEq(nft.owner(), govAddress, "NFT owner should be Gov contract");
        assertEq(nft.totalSupply(), 2, "NFT should have 2 tokens minted");
        assertEq(nft.ownerOf(0), alice, "First NFT not minted to alice");
        assertEq(nft.ownerOf(1), bob, "Second NFT not minted to bob");

        // Verify Gov initial state
        Gov gov = Gov(payable(govAddress));
        assertEq(gov.manifesto(), manifestoCid, "Manifesto mismatch");
        assertEq(gov.votingDelay(), votingDelay, "Voting delay mismatch");
        assertEq(gov.votingPeriod(), votingPeriod, "Voting period mismatch");

        // Verify deployment records in factory
        assertTrue(factory.hasDeployment(block.chainid), "Deployment not recorded");
        assertEq(factory.getDeploymentCount(), 1, "Deployment count mismatch");

        // Get deployment info and verify
        (address storedNft, address storedGov, uint256 chainId,, bool isHomeChain) = factory.deployments(block.chainid);

        assertEq(storedNft, nftAddress, "Stored NFT address mismatch");
        assertEq(storedGov, govAddress, "Stored Gov address mismatch");
        assertEq(chainId, block.chainid, "Chain ID mismatch");
        assertEq(isHomeChain, block.chainid == HOME_CHAIN_ID, "Home chain flag mismatch");
    }

    function testMultipleDeploymentsPrevention() public {
        // Set up and perform first deployment
        address[] memory initialMembers = new address[](1);
        initialMembers[0] = alice;

        vm.startPrank(deployer);
        factory.deployDAO(initialMembers, "QmManifestoCID", "First DAO", "DAO1", "ipfs://uri", 100, 1000, 0, 4);

        // Attempt a second deployment on the same chain
        vm.expectRevert(GovFactory.DeploymentAlreadyExists.selector);
        factory.deployDAO(initialMembers, "QmNewManifestoCID", "Second DAO", "DAO2", "ipfs://uri2", 200, 2000, 1, 5);
        vm.stopPrank();
    }

    function testOwnershipControl() public {
        address[] memory initialMembers = new address[](1);
        initialMembers[0] = alice;

        // Non-owner can't deploy
        vm.startPrank(alice);
        vm.expectRevert(GovFactory.OnlyOwner.selector);
        factory.deployDAO(initialMembers, "QmManifestoCID", "First DAO", "DAO1", "ipfs://uri", 100, 1000, 0, 4);
        vm.stopPrank();

        // Owner can transfer ownership
        vm.prank(deployer);
        factory.transferOwnership(alice);
        assertEq(factory.owner(), alice, "Ownership transfer failed");

        // Now alice can deploy
        vm.prank(alice);
        (nftAddress, govAddress) =
            factory.deployDAO(initialMembers, "QmManifestoCID", "First DAO", "DAO1", "ipfs://uri", 100, 1000, 0, 4);

        // Verify deployment was successful
        assertTrue(factory.hasDeployment(block.chainid), "Deployment not recorded");
    }
}
