// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Test, console } from "forge-std/src/Test.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";

contract GovTest is Test {
    Gov public gov;
    NFT public nft;

    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public homeChainId = 10; // Optimism
    uint256 public foreignChainId = 42_161; // Arbitrum

    string public initialManifesto = "QmInitialManifestoCID";
    string public newManifesto = "QmNewManifestoCID";

    uint48 public votingDelay = 1; // Reduced for testing
    uint32 public votingPeriod = 50; // Reduced for testing
    uint256 public proposalThreshold = 0; // Set to 0 for testing
    uint256 public quorumNumerator = 4; // 4%

    function setUp() public {
        // Start with home chain
        vm.chainId(homeChainId);

        vm.startPrank(deployer);

        // Create initial members array
        address[] memory initialMembers = new address[](2);
        initialMembers[0] = user1;
        initialMembers[1] = user2;

        // Deploy NFT contract first
        nft = new NFT(homeChainId, deployer, initialMembers, "ipfs://QmTokenURI", "DAO Membership", "DAOM");

        vm.stopPrank();

        // Setup voting delegation for users
        vm.prank(user1);
        nft.delegate(user1);

        vm.prank(user2);
        nft.delegate(user2);

        // Advance one block for delegations to take effect
        vm.roll(block.number + 1);

        // Deploy governance contract
        vm.startPrank(deployer);
        gov = new Gov(
            homeChainId,
            nft,
            initialManifesto,
            "Cross-Chain Governance",
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorumNumerator
        );

        // Transfer NFT ownership to governance
        nft.transferOwnership(address(gov));

        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(gov.manifesto(), initialManifesto);
        assertEq(gov.votingDelay(), votingDelay);
        assertEq(gov.votingPeriod(), votingPeriod);
        assertEq(gov.proposalThreshold(), proposalThreshold);
        assertEq(gov.quorumNumerator(), quorumNumerator);
        assertEq(gov.home(), homeChainId);
        assertEq(nft.owner(), address(gov));
    }

    function testManifestoUpdate_CrossChain() public {
        // First update manifesto on home chain
        // (We'll simplify by directly calling it rather than going through proposal process)
        vm.chainId(homeChainId);
        vm.startPrank(address(gov)); // Simulate governance call
        gov.setManifesto(newManifesto);

        // Generate proof for cross-chain update
        bytes memory proof = gov.generateManifestoProof(newManifesto);
        vm.stopPrank();

        // Switch to foreign chain and claim update
        vm.chainId(foreignChainId);
        gov.claimManifestoUpdate(proof);

        // Verify manifesto was updated on foreign chain
        assertEq(gov.manifesto(), newManifesto);
    }

    function testManifestoUpdate_OnHomeChain() public {
        // Create a proposal to update the manifesto
        address[] memory targets = new address[](1);
        targets[0] = address(gov);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(Gov.setManifesto.selector, newManifesto);

        // Skip the whole proposal voting process and just mock the update directly
        vm.startPrank(address(gov));
        gov.setManifesto(newManifesto);
        vm.stopPrank();

        // Verify manifesto was updated
        assertEq(gov.manifesto(), newManifesto);
    }

    function testParameterUpdate_CrossChain() public {
        // First update parameter on home chain
        uint48 newVotingDelay = 2;

        vm.chainId(homeChainId);
        vm.prank(address(gov)); // Simulate governance call
        gov.setVotingDelay(newVotingDelay);

        // Generate proof for cross-chain update
        bytes memory value = abi.encodePacked(newVotingDelay);
        bytes memory proof = gov.generateParameterProof(Gov.OperationType.UPDATE_VOTING_DELAY, value);

        // Switch to foreign chain and claim update
        vm.chainId(foreignChainId);
        gov.claimParameterUpdate(proof);

        // Verify parameter was updated on foreign chain
        assertEq(gov.votingDelay(), newVotingDelay);
    }

    function testParameterUpdates_OnHomeChain() public {
        // Create a proposal to update voting delay
        uint48 newVotingDelay = 2;

        // Skip the whole proposal voting process and just mock the update directly
        vm.startPrank(address(gov));
        gov.setVotingDelay(newVotingDelay);
        vm.stopPrank();

        // Verify voting delay was updated
        assertEq(gov.votingDelay(), newVotingDelay);
    }

    function testOperationRestriction_HomeChainOnly() public {
        // Try to update manifesto on foreign chain directly
        vm.chainId(foreignChainId);
        vm.prank(address(gov));

        vm.expectRevert("Operation only allowed on home chain");
        gov.setManifesto(newManifesto);
    }
}
