// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.29 <0.9.0;

import { BaseTest } from "../helpers/BaseTest.sol";
import { ProofHelper } from "../helpers/ProofHelper.sol";
import { NFT } from "../../src/NFT.sol";
import { Gov } from "../../src/Gov.sol";

/**
 * @title NFTTest
 * @notice Comprehensive unit tests for the NFT contract
 */
contract NFTTest is BaseTest {
    NFT public nft;
    Gov public gov;

    // Test constants
    string internal constant DEFAULT_NFT_NAME = "DAO Membership";
    string internal constant DEFAULT_NFT_SYMBOL = "DAOM";
    string internal constant DEFAULT_NFT_URI = "ipfs://QmTokenURI";
    string internal constant DEFAULT_MANIFESTO = "QmInitialManifestoCID";
    string internal constant DEFAULT_GOV_NAME = "Cross-Chain DAO";

    function setUp() public {
        setUpAccounts();
        vm.chainId(OPTIMISM);

        vm.startPrank(deployer);

        // Create initial members
        address[] memory initialMembers = createInitialMembers(2);

        // Deploy NFT
        nft = new NFT(OPTIMISM, deployer, initialMembers, DEFAULT_NFT_URI, DEFAULT_NFT_NAME, DEFAULT_NFT_SYMBOL);

        // Deploy governance
        gov = new Gov(
            OPTIMISM,
            nft,
            DEFAULT_MANIFESTO,
            DEFAULT_GOV_NAME,
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        // Transfer ownership to governance
        nft.transferOwnership(address(gov));

        vm.stopPrank();

        labelContracts(address(gov), address(nft));
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_SetsCorrectInitialState() public view {
        assertEq(nft.name(), DEFAULT_NFT_NAME);
        assertEq(nft.symbol(), DEFAULT_NFT_SYMBOL);
        assertEq(nft.HOME(), OPTIMISM);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.owner(), address(gov));
    }

    function test_constructor_MintsToInitialMembers() public view {
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
    }

    function test_constructor_SetsSelfDelegation() public view {
        assertEq(nft.getVotes(alice), 1);
        assertEq(nft.getVotes(bob), 1);
    }

    function test_constructor_SetsTokenURIs() public view {
        assertEq(nft.tokenURI(0), DEFAULT_NFT_URI);
        assertEq(nft.tokenURI(1), DEFAULT_NFT_URI);
    }

    /*//////////////////////////////////////////////////////////////
                    HOME CHAIN MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_safeMint_MintsTokenSuccessfully() public onHomeChain asUser(address(gov)) {
        uint256 supplyBefore = nft.totalSupply();

        nft.safeMint(charlie, "ipfs://QmCharlie");

        assertEq(nft.totalSupply(), supplyBefore + 1);
        assertEq(nft.balanceOf(charlie), 1);
        assertEq(nft.ownerOf(2), charlie);
        assertEq(nft.tokenURI(2), "ipfs://QmCharlie");
        assertTrue(nft.existsOnChain(2));
    }

    function test_safeMint_SetsSelfDelegation() public onHomeChain asUser(address(gov)) {
        nft.safeMint(charlie, "ipfs://QmCharlie");

        advanceBlocks(1);
        assertEq(nft.getVotes(charlie), 1);
    }

    function test_safeMint_RevertsWhen_CalledByNonOwner() public onHomeChain asUser(alice) {
        vm.expectRevert();
        nft.safeMint(charlie, "ipfs://QmCharlie");
    }

    function test_safeMint_RevertsWhen_OnForeignChain() public asUser(address(gov)) {
        vm.chainId(ARBITRUM);

        vm.expectRevert(NFT.OnlyHomeChainAllowed.selector);
        nft.safeMint(charlie, "ipfs://QmCharlie");
    }

    /*//////////////////////////////////////////////////////////////
                    OPERATOR MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setOperator_SetsOperatorSuccessfully() public onHomeChain asUser(address(gov)) {
        address newOperator = makeAddr("operator");

        vm.expectEmit(true, true, false, true);
        emit NFT.OperatorUpdated(address(0), newOperator);

        nft.setOperator(newOperator);

        assertEq(nft.operator(), newOperator);
    }

    function test_setOperator_RevertsWhen_CalledByNonOwner() public onHomeChain asUser(alice) {
        vm.expectRevert();
        nft.setOperator(alice);
    }

    function test_setOperator_RevertsWhen_OnForeignChain() public asUser(address(gov)) {
        vm.chainId(ARBITRUM);

        vm.expectRevert(NFT.OnlyHomeChainAllowed.selector);
        nft.setOperator(alice);
    }

    function test_operatorMint_MintsSuccessfully() public onHomeChain {
        address operator = makeAddr("operator");

        vm.prank(address(gov));
        nft.setOperator(operator);

        vm.prank(operator);
        nft.operatorMint(charlie, "ipfs://QmCharlie");

        assertEq(nft.balanceOf(charlie), 1);
        assertEq(nft.ownerOf(2), charlie);
    }

    function test_operatorMint_RevertsWhen_CalledByNonOperator() public onHomeChain asUser(alice) {
        vm.expectRevert(NFT.OnlyOperatorAllowed.selector);
        nft.operatorMint(charlie, "ipfs://QmCharlie");
    }

    function test_operatorMint_RevertsWhen_OnForeignChain() public {
        vm.chainId(OPTIMISM);
        address operator = makeAddr("operator");

        vm.prank(address(gov));
        nft.setOperator(operator);

        vm.chainId(ARBITRUM);

        vm.prank(operator);
        vm.expectRevert(NFT.OnlyHomeChainAllowed.selector);
        nft.operatorMint(charlie, "ipfs://QmCharlie");
    }

    function test_setOperatorDuration_UpdatesDuration() public onHomeChain asUser(address(gov)) {
        uint256 newDuration = 86_400; // 1 day

        vm.expectEmit(true, true, false, true);
        emit NFT.OperatorDurationUpdated(0, newDuration);

        nft.setOperatorDuration(newDuration);

        assertEq(nft.operatorDuration(), newDuration);
    }

    /*//////////////////////////////////////////////////////////////
                    HOME CHAIN BURNING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_govBurn_BurnsTokenSuccessfully() public onHomeChain asUser(address(gov)) {
        uint256 supplyBefore = nft.totalSupply();

        vm.expectEmit(true, true, false, true);
        emit NFT.MembershipRevoked(0, alice);

        nft.govBurn(0);

        assertEq(nft.totalSupply(), supplyBefore - 1);
        assertEq(nft.balanceOf(alice), 0);
        assertFalse(nft.existsOnChain(0));
    }

    function test_govBurn_RevertsWhen_CalledByNonOwner() public onHomeChain asUser(alice) {
        vm.expectRevert();
        nft.govBurn(0);
    }

    function test_govBurn_RevertsWhen_OnForeignChain() public asUser(address(gov)) {
        vm.chainId(ARBITRUM);

        vm.expectRevert(NFT.OnlyHomeChainAllowed.selector);
        nft.govBurn(0);
    }

    /*//////////////////////////////////////////////////////////////
                    METADATA UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setMetadata_UpdatesMetadataSuccessfully() public onHomeChain asUser(address(gov)) {
        string memory newUri = "ipfs://QmNewUri";

        vm.expectEmit(true, false, false, true);
        emit NFT.MetadataUpdated(0, newUri);

        nft.setMetadata(0, newUri);

        assertEq(nft.tokenURI(0), newUri);
    }

    function test_setMetadata_RevertsWhen_CalledByNonOwner() public onHomeChain asUser(alice) {
        vm.expectRevert();
        nft.setMetadata(0, "ipfs://QmNewUri");
    }

    function test_setMetadata_RevertsWhen_OnForeignChain() public asUser(address(gov)) {
        vm.chainId(ARBITRUM);

        vm.expectRevert(NFT.OnlyHomeChainAllowed.selector);
        nft.setMetadata(0, "ipfs://QmNewUri");
    }

    /*//////////////////////////////////////////////////////////////
                    DELEGATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_delegate_UpdatesVotingPower() public onHomeChain asUser(alice) {
        nft.delegate(bob);

        advanceBlocks(1);

        assertEq(nft.getVotes(alice), 0);
        assertEq(nft.getVotes(bob), 2);
    }

    function test_delegate_UpdatesCrosschainDelegates() public onHomeChain asUser(alice) {
        nft.delegate(bob);

        assertEq(nft.crosschainDelegates(alice), bob);
    }

    function test_delegate_EmitsDelegationUpdated() public onHomeChain asUser(alice) {
        vm.expectEmit(true, true, false, true);
        emit NFT.DelegationUpdated(alice, bob);

        nft.delegate(bob);
    }

    function test_delegate_RevertsWhen_OnForeignChain() public asUser(alice) {
        vm.chainId(ARBITRUM);

        vm.expectRevert(NFT.OnlyHomeChainAllowed.selector);
        nft.delegate(bob);
    }

    function test_delegate_AllowsChangingDelegate() public onHomeChain asUser(alice) {
        // First delegation
        nft.delegate(bob);
        advanceBlocks(1);
        assertEq(nft.getVotes(bob), 2);

        // Change delegation
        nft.delegate(charlie);
        advanceBlocks(1);

        assertEq(nft.getVotes(bob), 1);
        assertEq(nft.getVotes(charlie), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    NON-TRANSFERABLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferFrom_RevertsAlways() public asUser(alice) {
        vm.expectRevert(NFT.NFTNonTransferable.selector);
        nft.transferFrom(alice, bob, 0);
    }

    function test_safeTransferFrom_RevertsAlways() public asUser(alice) {
        vm.expectRevert(NFT.NFTNonTransferable.selector);
        nft.safeTransferFrom(alice, bob, 0);
    }

    function test_approve_AllowedButTransferReverts() public asUser(alice) {
        // Approve is allowed (though useless since transfers revert)
        nft.approve(bob, 0);
        assertEq(nft.getApproved(0), bob);

        // But transfer still reverts
        vm.expectRevert(NFT.NFTNonTransferable.selector);
        nft.transferFrom(alice, charlie, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    INTERFACE SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface_ReturnsTrue_ForERC721() public view {
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC721
    }

    function test_supportsInterface_ReturnsTrue_ForERC721Enumerable() public view {
        assertTrue(nft.supportsInterface(0x780e9d63)); // ERC721Enumerable
    }

    /*//////////////////////////////////////////////////////////////
                    CLOCK MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_clock_ReturnsCurrentTimestamp() public view {
        assertEq(nft.clock(), uint48(block.timestamp));
    }

    function test_CLOCK_MODE_ReturnsTimestampMode() public view {
        assertEq(nft.CLOCK_MODE(), "mode=timestamp");
    }
}
