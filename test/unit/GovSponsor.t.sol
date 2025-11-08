// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Gov } from "../../src/Gov.sol";
import { NFT } from "../../src/NFT.sol";
import { GovSponsor } from "../../src/extensions/GovSponsor.sol";

/**
 * @title GovSponsorTest
 * @notice Tests for Gov contract UserOperation mechanism for gasless interactions
 * @dev Tests that members can interact with ABSOLUTE ZERO ETH via UserOperations
 */
contract GovSponsorTest is Test {
    Gov public gov;
    NFT public nft;

    address payable public alice;
    address payable public bob;
    address payable public nonMember;

    uint256 public aliceKey;
    uint256 public bobKey;
    uint256 public nonMemberKey;

    // Mock target contract for testing
    MockTarget public mockTarget;

    event UserOperationExecuted(address indexed sender, uint256 nonce, bool success, uint256 gasUsed);

    function setUp() public {
        // Create private keys and derive addresses
        aliceKey = 0xA11CE;
        bobKey = 0xB0B;
        nonMemberKey = 0xDEAD;

        alice = payable(vm.addr(aliceKey));
        bob = payable(vm.addr(bobKey));
        nonMember = payable(vm.addr(nonMemberKey));

        // Deploy NFT contract with Alice and Bob as initial members
        address[] memory firstMembers = new address[](2);
        firstMembers[0] = alice;
        firstMembers[1] = bob;

        nft = new NFT(
            block.chainid, // home chain
            address(this), // initial owner (this test contract acts as governance)
            firstMembers,
            "ipfs://QmTest",
            "DAO Membership",
            "MEMBER"
        );

        // Deploy Gov contract
        gov = new Gov(
            block.chainid, // home chain
            nft, // voting token
            "QmTestManifesto",
            "Test DAO",
            1, // voting delay
            100, // voting period
            0, // proposal threshold
            4 // quorum (4%)
        );

        // Transfer NFT ownership to Gov contract
        nft.transferOwnership(address(gov));

        // Fund the gov contract treasury (members will never need ETH)
        vm.deal(address(gov), 100 ether);

        // Give Alice and Bob ZERO ETH - they don't need any!
        vm.deal(alice, 0);
        vm.deal(bob, 0);

        // Give nonMember some ETH (they won't be able to use UserOps anyway)
        vm.deal(nonMember, 10 ether);

        // Deploy mock target contract
        mockTarget = new MockTarget();
    }

    /**
     * @notice Test UserOperation with ABSOLUTE ZERO ETH - propose
     * @dev Alice signs a UserOp offline, anyone can submit it
     */
    function testUserOpProposeWithZeroETH() public {
        // Verify Alice has ABSOLUTE ZERO ETH
        assertEq(alice.balance, 0, "Alice must have ZERO ETH");

        // Prepare the call data for propose
        address[] memory targets = new address[](1);
        targets[0] = address(mockTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 777);

        bytes memory callData = abi.encodeWithSignature(
            "propose(address[],uint256[],bytes[],string)", targets, values, calldatas, "UserOp Proposal"
        );

        // Create and sign UserOperation
        GovSponsor.UserOperation memory userOp = GovSponsor.UserOperation({
            sender: alice,
            nonce: gov.getNonce(alice),
            callData: callData,
            callGasLimit: 500_000,
            verificationGasLimit: 100_000,
            preVerificationGas: 21_000,
            maxFeePerGas: tx.gasprice,
            maxPriorityFeePerGas: tx.gasprice,
            signature: new bytes(65)
        });

        // Alice signs offline (with ZERO ETH)
        bytes32 userOpHash = gov.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        // Bob (or anyone) submits it
        vm.prank(bob);
        bool success = gov.executeUserOp(userOp);

        assertTrue(success, "UserOp should succeed");
        assertEq(alice.balance, 0, "Alice should still have ZERO ETH");
        assertGt(gov.gasSpent(alice), 0, "Gas should be tracked for Alice");
    }

    /**
     * @notice Test complete governance workflow with ZERO ETH
     */
    function testCompleteWorkflowWithZeroETH() public {
        // Both members have ZERO ETH
        assertEq(alice.balance, 0);
        assertEq(bob.balance, 0);

        // 1. Alice proposes via UserOp
        address[] memory targets = new address[](1);
        targets[0] = address(mockTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 42);

        bytes memory proposeData =
            abi.encodeWithSignature("propose(address[],uint256[],bytes[],string)", targets, values, calldatas, "Test");
        GovSponsor.UserOperation memory proposeOp = _createUserOp(alice, aliceKey, proposeData);
        vm.prank(bob);
        gov.executeUserOp(proposeOp);

        // Get the proposal ID from the proposalIds array
        uint256 proposalId = gov.proposalIds(0);

        // 2. Wait for voting to become active (voting delay = 1 second)
        vm.warp(block.timestamp + 2);

        bytes memory voteData = abi.encodeWithSignature("castVote(uint256,uint8)", proposalId, 1);
        GovSponsor.UserOperation memory voteOp1 = _createUserOp(alice, aliceKey, voteData);
        vm.prank(alice); // Alice can submit her own UserOp if she wants (but still pays no gas)
        gov.executeUserOp(voteOp1);

        GovSponsor.UserOperation memory voteOp2 = _createUserOp(bob, bobKey, voteData);
        vm.prank(alice); // Or Alice submits for Bob
        gov.executeUserOp(voteOp2);

        // 3. Wait for voting period to end (voting period = 100 seconds)
        // Proposal was created at T0, voting starts at T0+1, ends at T0+101
        // We're at T0+2, so need to wait 100 more seconds minimum
        // Add extra to ensure we're past the deadline
        vm.warp(block.timestamp + 101);

        bytes memory executeData = abi.encodeWithSignature(
            "execute(address[],uint256[],bytes[],bytes32)", targets, values, calldatas, keccak256(bytes("Test"))
        );
        GovSponsor.UserOperation memory executeOp = _createUserOp(alice, aliceKey, executeData);
        vm.prank(bob);
        gov.executeUserOp(executeOp);

        // Verify execution
        assertEq(mockTarget.value(), 42);
        assertEq(alice.balance, 0, "Alice never needed ETH");
        assertEq(bob.balance, 0, "Bob never needed ETH");
    }

    /**
     * @notice Test that non-members cannot use UserOp
     */
    function testUserOpRevertsForNonMember() public {
        bytes memory callData = abi.encodeWithSignature(
            "propose(address[],uint256[],bytes[],string)", new address[](0), new uint256[](0), new bytes[](0), "Test"
        );

        GovSponsor.UserOperation memory userOp = GovSponsor.UserOperation({
            sender: nonMember,
            nonce: 0,
            callData: callData,
            callGasLimit: 100_000,
            verificationGasLimit: 50_000,
            preVerificationGas: 21_000,
            maxFeePerGas: tx.gasprice,
            maxPriorityFeePerGas: tx.gasprice,
            signature: new bytes(65)
        });

        bytes32 userOpHash = gov.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nonMemberKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSignature("NotAMember()"));
        gov.executeUserOp(userOp);
    }

    /**
     * @notice Test that invalid signature is rejected
     */
    function testUserOpRevertsOnInvalidSignature() public {
        bytes memory callData = abi.encodeWithSignature("castVote(uint256,uint8)", 1, 1);

        GovSponsor.UserOperation memory userOp = GovSponsor.UserOperation({
            sender: alice,
            nonce: gov.getNonce(alice),
            callData: callData,
            callGasLimit: 100_000,
            verificationGasLimit: 50_000,
            preVerificationGas: 21_000,
            maxFeePerGas: tx.gasprice,
            maxPriorityFeePerGas: tx.gasprice,
            signature: new bytes(65)
        });

        bytes32 userOpHash = gov.getUserOpHash(userOp);
        // Sign with wrong key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSignature("InvalidUserOpSignature()"));
        gov.executeUserOp(userOp);
    }

    /**
     * @notice Test that nonce replay is prevented
     */
    function testUserOpRevertsOnNonceReplay() public {
        bytes memory callData = abi.encodeWithSignature("castVote(uint256,uint8)", 1, 1);

        GovSponsor.UserOperation memory userOp = _createUserOp(alice, aliceKey, callData);

        // First execution succeeds
        gov.executeUserOp(userOp);

        // Second execution with same nonce fails
        vm.expectRevert(abi.encodeWithSignature("InvalidNonce()"));
        gov.executeUserOp(userOp);
    }

    /**
     * @notice Test membership check
     */
    function testIsMember() public view {
        assertTrue(gov.isMember(alice), "Alice should be a member");
        assertTrue(gov.isMember(bob), "Bob should be a member");
        assertFalse(gov.isMember(nonMember), "Non-member should not be a member");
    }

    /**
     * @notice Test gas tracking
     */
    function testGasTracking() public {
        bytes memory callData1 = abi.encodeWithSignature("castVote(uint256,uint8)", 1, 1);
        GovSponsor.UserOperation memory userOp1 = _createUserOp(alice, aliceKey, callData1);
        gov.executeUserOp(userOp1);

        uint256 gasAfterFirst = gov.gasSpent(alice);
        assertGt(gasAfterFirst, 0);

        bytes memory callData2 = abi.encodeWithSignature("castVote(uint256,uint8)", 2, 1);
        GovSponsor.UserOperation memory userOp2 = _createUserOp(alice, aliceKey, callData2);
        gov.executeUserOp(userOp2);

        uint256 gasAfterSecond = gov.gasSpent(alice);
        assertGt(gasAfterSecond, gasAfterFirst, "Gas should accumulate");
    }

    /**
     * @notice Helper to create and sign a UserOp
     */
    function _createUserOp(
        address sender,
        uint256 privateKey,
        bytes memory callData
    )
        internal
        view
        returns (GovSponsor.UserOperation memory)
    {
        GovSponsor.UserOperation memory userOp = GovSponsor.UserOperation({
            sender: sender,
            nonce: gov.getNonce(sender),
            callData: callData,
            callGasLimit: 500_000,
            verificationGasLimit: 100_000,
            preVerificationGas: 21_000,
            maxFeePerGas: tx.gasprice,
            maxPriorityFeePerGas: tx.gasprice,
            signature: new bytes(65)
        });

        bytes32 userOpHash = gov.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);

        return userOp;
    }
}

/**
 * @title MockTarget
 * @notice Mock contract for testing governance proposals
 */
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external payable {
        value = _value;
    }

    receive() external payable { }
}
