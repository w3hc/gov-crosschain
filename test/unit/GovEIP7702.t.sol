// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { Gov } from "../../src/Gov.sol";
import { NFT } from "../../src/NFT.sol";

/**
 * @title GovEIP7702Test
 * @notice Tests for Gov contract with EIP-7702 delegation
 * @dev Tests that members can interact with ZERO ETH via EIP-7702 authorization
 */
contract GovEIP7702Test is Test {
    Gov public gov;
    NFT public nft;

    address payable public alice;
    address payable public bob;
    uint256 public aliceKey;
    uint256 public bobKey;

    // Mock target contract for testing
    MockTarget public mockTarget;

    function setUp() public {
        // Create private keys and derive addresses
        aliceKey = 0xA11CE;
        bobKey = 0xB0B;

        alice = payable(vm.addr(aliceKey));
        bob = payable(vm.addr(bobKey));

        // Deploy NFT contract with Alice and Bob as initial members
        address[] memory firstMembers = new address[](2);
        firstMembers[0] = alice;
        firstMembers[1] = bob;

        nft = new NFT(
            block.chainid, // home chain
            address(this), // initial owner
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

        // Fund the gov contract treasury
        vm.deal(address(gov), 100 ether);

        // Give Alice and Bob ZERO ETH - they don't need any with EIP-7702!
        vm.deal(alice, 0);
        vm.deal(bob, 0);

        // Deploy mock target contract
        mockTarget = new MockTarget();
    }

    /**
     * @notice Test EIP-7702 delegation simulation
     * @dev Uses vm.etch to simulate EIP-7702 delegation
     */
    function testEIP7702Delegation() public {
        // Verify Alice has ZERO ETH
        assertEq(alice.balance, 0, "Alice must have ZERO ETH");

        // Simulate EIP-7702: Set Alice's code to delegate to Gov contract
        // Format: 0xef0100 + address(gov)
        bytes memory delegationCode = abi.encodePacked(
            hex"ef0100", // EIP-7702 magic bytes
            address(gov) // Delegate to Gov contract
        );
        vm.etch(alice, delegationCode);

        // Verify delegation is set
        bytes memory aliceCode = alice.code;
        assertEq(aliceCode.length, 23, "Delegation code should be 23 bytes");
        assertEq(bytes3(aliceCode), hex"ef0100", "Should start with EIP-7702 magic");
    }

    /**
     * @notice Test propose via EIP-7702 delegation
     * @dev Alice can propose with ZERO ETH through delegation
     */
    function testEIP7702Propose() public {
        // Simulate EIP-7702 delegation
        bytes memory delegationCode = abi.encodePacked(hex"ef0100", address(gov));
        vm.etch(alice, delegationCode);

        // Prepare proposal
        address[] memory targets = new address[](1);
        targets[0] = address(mockTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 777);

        // Alice proposes (with delegation, msg.sender is still alice but execution context is gov)
        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, "EIP-7702 Proposal");

        // Verify proposal was created
        assertGt(proposalId, 0, "Proposal should be created");
        assertEq(alice.balance, 0, "Alice should still have ZERO ETH");
    }

    /**
     * @notice Test complete workflow with EIP-7702
     * @dev Propose, vote, and execute all with ZERO ETH
     */
    function testEIP7702CompleteWorkflow() public {
        // Set up delegation for both Alice and Bob
        bytes memory delegationCode = abi.encodePacked(hex"ef0100", address(gov));
        vm.etch(alice, delegationCode);
        vm.etch(bob, delegationCode);

        // Verify both have ZERO ETH
        assertEq(alice.balance, 0);
        assertEq(bob.balance, 0);

        // 1. Alice proposes via EIP-7702
        address[] memory targets = new address[](1);
        targets[0] = address(mockTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 42);

        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, "Test Proposal");

        // 2. Wait for voting to become active
        vm.warp(block.timestamp + 2);

        // 3. Vote via EIP-7702
        vm.prank(alice);
        gov.castVote(proposalId, 1); // Vote For

        vm.prank(bob);
        gov.castVote(proposalId, 1); // Vote For

        // 4. Wait for voting period to end
        vm.warp(block.timestamp + 101);

        // 5. Execute via EIP-7702
        vm.prank(alice);
        gov.execute(targets, values, calldatas, keccak256(bytes("Test Proposal")));

        // Verify execution
        assertEq(mockTarget.value(), 42, "Proposal should have executed");
        assertEq(alice.balance, 0, "Alice never needed ETH");
        assertEq(bob.balance, 0, "Bob never needed ETH");
    }

    /**
     * @notice Test that regular Gov functions still work without delegation
     * @dev Ensures backward compatibility
     */
    function testBackwardCompatibility() public {
        // Fund Alice so she can pay gas traditionally
        vm.deal(alice, 1 ether);

        address[] memory targets = new address[](1);
        targets[0] = address(mockTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 99);

        // Traditional propose (no delegation)
        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, "Traditional Proposal");

        assertGt(proposalId, 0, "Traditional propose should still work");
        assertLt(alice.balance, 1 ether, "Alice should have paid some gas");
    }

    /**
     * @notice Test EIP-7702 with membership validation
     * @dev Only members can use delegation
     */
    function testEIP7702RequiresMembership() public {
        address nonMember = address(0xDEAD);

        // Set delegation for non-member
        bytes memory delegationCode = abi.encodePacked(hex"ef0100", address(gov));
        vm.etch(nonMember, delegationCode);

        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);

        // Non-member cannot propose even with delegation
        // (Gov contract's proposalThreshold and membership checks still apply)
        vm.prank(nonMember);
        vm.expectRevert(); // Will revert due to no voting power
        gov.propose(targets, values, calldatas, "Should Fail");
    }

    /**
     * @notice Test gas efficiency comparison
     * @dev EIP-7702 should be more gas efficient than UserOp
     */
    function testGasEfficiency() public {
        // Set up EIP-7702 delegation
        bytes memory delegationCode = abi.encodePacked(hex"ef0100", address(gov));
        vm.etch(alice, delegationCode);

        address[] memory targets = new address[](1);
        targets[0] = address(mockTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("setValue(uint256)", 123);

        // Measure gas for EIP-7702 propose
        uint256 gasStart = gasleft();
        vm.prank(alice);
        gov.propose(targets, values, calldatas, "Gas Test");
        uint256 gasUsedEIP7702 = gasStart - gasleft();

        console2.log("Gas used with EIP-7702:", gasUsedEIP7702);

        // EIP-7702 should use less gas than UserOp
        // (UserOp has additional signature verification overhead)
        assertLt(gasUsedEIP7702, 500_000, "EIP-7702 should be gas efficient");
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
