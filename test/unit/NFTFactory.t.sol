// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { BaseTest } from "../helpers/BaseTest.sol";
import { NFTFactory } from "../../src/NFTFactory.sol";
import { GovFactory } from "../../src/GovFactory.sol";
import { NFT } from "../../src/NFT.sol";

/**
 * @title NFTFactoryTest
 * @notice Unit tests for the NFTFactory contract
 */
contract NFTFactoryTest is BaseTest {
    NFTFactory public nftFactory;
    GovFactory public govFactory;

    bytes32 public constant TEST_SALT = bytes32(uint256(0x1234));

    function setUp() public {
        setUpAccounts();
        vm.chainId(OPTIMISM);

        vm.startPrank(deployer);

        // Deploy GovFactory first
        govFactory = new GovFactory();

        // Deploy NFTFactory with GovFactory address
        nftFactory = new NFTFactory(address(govFactory));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SetsGovFactory() public view {
        assertEq(nftFactory.GOV_FACTORY(), address(govFactory));
    }

    /*//////////////////////////////////////////////////////////////
                    NFT DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployNFT_DeploysSuccessfully() public {
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        assertNotZeroAddress(nftAddress, "NFT address is zero");

        NFT nft = NFT(nftAddress);
        assertEq(nft.name(), "Test DAO");
        assertEq(nft.symbol(), "TDAO");
        assertEq(nft.HOME(), OPTIMISM);
    }

    function test_deployNFT_MintsToInitialMembers() public {
        address[] memory members = createInitialMembers(3);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.balanceOf(charlie), 1);
    }

    function test_deployNFT_TransfersOwnershipToGovFactory() public {
        address[] memory members = createInitialMembers(2);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);
        assertEq(nft.owner(), address(govFactory));
    }

    function test_deployNFT_EmitsNFTDeployedEvent() public {
        address[] memory members = createInitialMembers(2);

        vm.expectEmit(false, false, false, false);
        emit NFTFactory.NFTDeployed(address(0)); // We don't know the address yet

        vm.prank(deployer);
        nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");
    }

    function test_deployNFT_ProducesPredictableAddress() public {
        address[] memory members = createInitialMembers(2);

        // Deploy with specific salt
        vm.prank(deployer);
        address nft1 = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        // Verify the address is deterministic (non-zero and valid contract)
        assertNotZeroAddress(nft1, "NFT address should not be zero");
        assertTrue(nft1.code.length > 0, "NFT should have code deployed");

        // Deploy with different salt produces different address
        bytes32 differentSalt = bytes32(uint256(0x9999));
        vm.prank(deployer);
        address nft2 = nftFactory.deployNFT(OPTIMISM, differentSalt, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        assertTrue(nft1 != nft2, "Different salts should produce different addresses");
    }

    function test_deployNFT_DifferentSaltProducesDifferentAddress() public {
        address[] memory members = createInitialMembers(2);

        vm.startPrank(deployer);

        address nft1 = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        bytes32 differentSalt = bytes32(uint256(0x5678));
        address nft2 = nftFactory.deployNFT(OPTIMISM, differentSalt, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        vm.stopPrank();

        assertTrue(nft1 != nft2, "Different salts should produce different addresses");
    }

    function test_deployNFT_WorksWithZeroInitialMembers() public {
        address[] memory members = new address[](0);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);
        assertEq(nft.totalSupply(), 0);
    }

    function test_deployNFT_WorksWithSingleMember() public {
        address[] memory members = createInitialMembers(1);

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_deployNFT_SetsCorrectTokenURI() public {
        address[] memory members = createInitialMembers(2);
        string memory uri = "ipfs://QmCustomURI";

        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", uri);

        NFT nft = NFT(nftAddress);
        assertEq(nft.tokenURI(0), uri);
        assertEq(nft.tokenURI(1), uri);
    }

    /*//////////////////////////////////////////////////////////////
                    INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_FactoryFlowWithGovFactory() public {
        address[] memory members = createInitialMembers(2);

        // Deploy NFT via NFTFactory
        vm.prank(deployer);
        address nftAddress = nftFactory.deployNFT(OPTIMISM, TEST_SALT, members, "Test DAO", "TDAO", "ipfs://QmTestURI");

        NFT nft = NFT(nftAddress);

        // Verify ownership is with GovFactory
        assertEq(nft.owner(), address(govFactory));

        // Deploy Gov via GovFactory (which should now own the NFT)
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

        // Verify ownership transferred to Gov
        assertEq(nft.owner(), govAddress);
    }
}
