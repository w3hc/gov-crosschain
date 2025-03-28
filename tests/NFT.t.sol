// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { NFT } from "../src/NFT.sol";

contract NFTTest is Test {
    NFT public homeNft; // Home chain NFT
    NFT public foreignNft; // Foreign chain NFT

    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    uint256 public homeChainId = 10; // Optimism
    uint256 public foreignChainId = 42_161; // Arbitrum

    string public initialTokenURI = "ipfs://QmInitialTokenURI";
    string public newTokenURI = "ipfs://QmNewTokenURI";

    // Track token IDs
    uint256 public tokenId0;
    uint256 public tokenId1;
    uint256 public tokenId2;

    function setUp() public {
        // Start on home chain
        vm.chainId(homeChainId);

        vm.startPrank(deployer);

        // Create initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = user1;
        initialMembers[1] = user2;

        // Deploy NFT contract on home chain
        homeNft = new NFT(homeChainId, deployer, initialMembers, initialTokenURI, "DAO Membership", "DAOM");

        // The first two tokens are minted to user1 and user2 (IDs 0 and 1)
        tokenId0 = 0;
        tokenId1 = 1;

        // Switch to foreign chain
        vm.chainId(foreignChainId);

        // Deploy the same NFT contract on foreign chain with the same parameters
        // but no initial members
        foreignNft = new NFT(
            homeChainId, // Still set home chain ID as the official home
            deployer,
            new address[](0), // No initial members on foreign chain
            initialTokenURI,
            "DAO Membership",
            "DAOM"
        );

        // Switch back to home chain
        vm.chainId(homeChainId);
        vm.stopPrank();
    }

    function testInitialState() public view {
        // Check token ownership
        assertEq(homeNft.ownerOf(tokenId0), user1);
        assertEq(homeNft.ownerOf(tokenId1), user2);

        // Check token URI
        assertEq(homeNft.tokenURI(tokenId0), initialTokenURI);
        assertEq(homeNft.tokenURI(tokenId1), initialTokenURI);

        // Check token existence
        assertTrue(homeNft.existsOnChain(tokenId0));
        assertTrue(homeNft.existsOnChain(tokenId1));

        // Check contract owner
        assertEq(homeNft.owner(), deployer);

        // Check home chain
        assertEq(homeNft.home(), homeChainId);
    }

    function testSafeMint_OnHomeChain() public {
        vm.startPrank(deployer);

        // Mint new token to user3
        homeNft.safeMint(user3, initialTokenURI);

        // Token ID should be 2 (after 0 and 1)
        tokenId2 = 2;
        assertEq(homeNft.ownerOf(tokenId2), user3);
        assertEq(homeNft.tokenURI(tokenId2), initialTokenURI);
        assertTrue(homeNft.existsOnChain(tokenId2));

        vm.stopPrank();
    }

    function testNonTransferable() public {
        vm.startPrank(user1);

        // Try to transfer token from user1 to user3
        vm.expectRevert("NFT is not transferable");
        homeNft.transferFrom(user1, user3, tokenId0);

        vm.stopPrank();
    }

    function testBurn_OnHomeChain() public {
        vm.prank(deployer);
        homeNft.govBurn(tokenId0);

        // Token should no longer exist
        assertFalse(homeNft.existsOnChain(tokenId0));

        // ownerOf should revert with ERC721NonexistentToken error
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", tokenId0));
        homeNft.ownerOf(tokenId0);
    }

    function testSetMetadata_OnHomeChain() public {
        vm.prank(deployer);
        homeNft.setMetadata(tokenId0, newTokenURI);

        // Token URI should be updated
        assertEq(homeNft.tokenURI(tokenId0), newTokenURI);
    }

    function testOperationRestriction_HomeChainOnly() public {
        // Try to mint on foreign chain directly
        vm.chainId(foreignChainId);
        vm.prank(deployer);

        vm.expectRevert("Operation only allowed on home chain");
        foreignNft.safeMint(user3, initialTokenURI);
    }
}
