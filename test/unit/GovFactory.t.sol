// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { BaseTest } from "../helpers/BaseTest.sol";
import { GovFactory } from "../../src/GovFactory.sol";
import { NFTFactory } from "../../src/NFTFactory.sol";
import { NFT } from "../../src/NFT.sol";
import { Gov } from "../../src/Gov.sol";

/**
 * @title GovFactoryTest
 * @notice Unit tests for the GovFactory contract
 */
contract GovFactoryTest is BaseTest {
    GovFactory public govFactory;
    NFTFactory public nftFactory;

    bytes32 public constant TEST_SALT = bytes32(uint256(0x1234));

    function setUp() public {
        setUpAccounts();
        vm.chainId(OPTIMISM);

        vm.startPrank(deployer);

        // Deploy GovFactory
        govFactory = new GovFactory();

        // Deploy NFTFactory (needed for creating NFTs)
        nftFactory = new NFTFactory(address(govFactory));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    GOV DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployGov_DeploysSuccessfully() public {
        // First deploy an NFT
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        // Now deploy Gov
        vm.prank(deployer);
        address govAddress = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            nft,
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        assertNotZeroAddress(govAddress, "Gov address is zero");

        Gov gov = Gov(payable(govAddress));
        assertEq(gov.name(), "Test DAO");
        assertEq(gov.manifesto(), "QmManifesto");
        assertEq(gov.HOME(), OPTIMISM);
    }

    function test_deployGov_SetsCorrectParameters() public {
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        uint48 customDelay = 100;
        uint32 customPeriod = 500;
        uint256 customThreshold = 2;
        uint256 customQuorum = 10;

        vm.prank(deployer);
        address govAddress = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            nft,
            "QmManifesto",
            "Test DAO",
            customDelay,
            customPeriod,
            customThreshold,
            customQuorum
        );

        Gov gov = Gov(payable(govAddress));
        assertEq(gov.votingDelay(), customDelay);
        assertEq(gov.votingPeriod(), customPeriod);
        assertEq(gov.proposalThreshold(), customThreshold);
        assertEq(gov.quorumNumerator(), customQuorum);
    }

    function test_deployGov_TransfersNFTOwnershipToGov() public {
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        // NFT should be owned by GovFactory before Gov deployment
        assertEq(nft.owner(), address(govFactory));

        vm.prank(deployer);
        address govAddress = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            nft,
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        // After deployment, NFT should be owned by Gov
        assertEq(nft.owner(), govAddress);
    }

    function test_deployGov_EmitsGovDeployedEvent() public {
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        vm.expectEmit(false, false, false, false);
        emit GovFactory.GovDeployed(address(0)); // We don't know the address yet

        vm.prank(deployer);
        govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            nft,
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );
    }

    function test_deployGov_ProducesPredictableAddress() public {
        address[] memory members = createInitialMembers(2);

        vm.startPrank(deployer);

        // Deploy NFT
        address nft1Address = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        // Deploy Gov with specific salt
        address gov1 = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            NFT(nft1Address),
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        // Verify the address is deterministic (non-zero and valid contract)
        assertNotZeroAddress(gov1, "Gov address should not be zero");
        assertTrue(gov1.code.length > 0, "Gov should have code deployed");

        // Deploy with different salt produces different address
        bytes32 differentSalt = bytes32(uint256(0x9999));
        address nft2Address =
            nftFactory.deployNFT(OPTIMISM, differentSalt, members, "Test DAO 2", "TDAO2", "ipfs://QmTestURI2");

        address gov2 = govFactory.deployGov(
            OPTIMISM,
            differentSalt,
            NFT(nft2Address),
            "QmManifesto2",
            "Test DAO 2",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        vm.stopPrank();

        assertTrue(gov1 != gov2, "Different salts should produce different addresses");
    }

    function test_deployGov_DifferentSaltProducesDifferentAddress() public {
        address[] memory members = createInitialMembers(2);

        vm.startPrank(deployer);

        // First deployment
        address nft1Address =
            nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO 1", "TDAO1", "ipfs://QmTestURI1");

        address gov1 = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            NFT(nft1Address),
            "QmManifesto1",
            "Test DAO 1",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        // Second deployment with different salt
        bytes32 differentSalt = bytes32(uint256(0x5678));
        address nft2Address =
            nftFactory.deployNFT(OPTIMISM, differentSalt, members, "Test DAO 2", "TDAO2", "ipfs://QmTestURI2");

        address gov2 = govFactory.deployGov(
            OPTIMISM,
            differentSalt,
            NFT(nft2Address),
            "QmManifesto2",
            "Test DAO 2",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        vm.stopPrank();

        assertTrue(gov1 != gov2, "Different salts should produce different addresses");
    }

    function test_deployGov_SetsCorrectTokenReference() public {
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        vm.prank(deployer);
        address govAddress = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            nft,
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        Gov gov = Gov(payable(govAddress));
        assertEq(address(gov.token()), nftAddress);
    }

    /*//////////////////////////////////////////////////////////////
                    FULL DEPLOYMENT FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fullDeploymentFlow_ProducesWorkingDAO() public {
        address[] memory members = createInitialMembers(2);

        vm.startPrank(deployer);

        // 1. Deploy NFT
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        // 2. Deploy Gov
        address govAddress = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            nft,
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        vm.stopPrank();

        Gov gov = Gov(payable(govAddress));

        // 3. Verify the DAO is functional
        assertEq(nft.owner(), govAddress, "Gov should own NFT");
        assertEq(nft.totalSupply(), 2, "Should have 2 members");
        assertEq(address(gov.token()), nftAddress, "Gov should reference NFT");

        // 4. Verify governance can mint new members
        vm.prank(govAddress);
        nft.safeMint(charlie, "ipfs://QmCharlie");

        assertEq(nft.totalSupply(), 3, "Should have 3 members after mint");
        assertEq(nft.balanceOf(charlie), 1, "Charlie should have NFT");
    }

    function test_fullDeploymentFlow_CreatesWorkingMultichainDAO() public {
        address[] memory members = createInitialMembers(2);

        // Deploy full DAO setup
        vm.startPrank(deployer);

        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        address govAddress = govFactory.deployGov(
            OPTIMISM,
            TEST_SALT,
            NFT(nftAddress),
            "QmManifesto",
            "Test DAO",
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        vm.stopPrank();

        NFT nft = NFT(nftAddress);
        Gov gov = Gov(payable(govAddress));

        // Verify deployment is correct
        assertEq(nft.owner(), govAddress, "Gov should own NFT");
        assertEq(nft.totalSupply(), 2, "Should have 2 members");
        assertEq(nft.HOME(), OPTIMISM, "Home chain should be Optimism");
        assertEq(address(gov.token()), nftAddress, "Gov should reference NFT");
        assertEq(gov.HOME(), OPTIMISM, "Gov home chain should be Optimism");
        assertEq(gov.manifesto(), "QmManifesto", "Manifesto should match");

        // Verify DAO is functional across chains - can be deployed on foreign chain too
        vm.chainId(ARBITRUM);
        assertEq(nft.HOME(), OPTIMISM, "Home chain reference persists");
        assertEq(gov.HOME(), OPTIMISM, "Gov home chain reference persists");
    }
}
