// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

/**
 * @title AddMemberProposal
 * @notice Creates, votes on, and executes a proposal in one script
 */
contract AddMemberProposal is Script {
    // Contract addresses
    address public govAddressChainA = 0x78FBfD9AaaD967d54C354a34A131EF72946Ded1F;
    address public nftAddressChainA = 0xF71F50CD291BEfABE178e1A75112Ef6d051B5824;
    address public govAddressChainB = 0x38F52D3581926B4D28cE261098E32cE3E75A5DB1;
    address public nftAddressChainB = 0x78FBfD9AaaD967d54C354a34A131EF72946Ded1F;

    // Chain IDs
    uint256 public chainAId = 901; // OPChainA
    uint256 public chainBId = 902; // OPChainB

    // Account addresses
    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bob = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public francis = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    // Private keys
    uint256 public aliceKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public bobKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 public francisKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // Token URI
    string public constant TOKEN_URI = "ipfs://QmFrancisTokenURI";

    function run() public {
        // Get contract instances
        Gov gov = Gov(payable(govAddressChainA));
        NFT nft = NFT(nftAddressChainA);

        console2.log("Gov contract address: %s", address(gov));
        console2.log("NFT contract address: %s", address(nft));

        console2.log("Gov home chain ID:", gov.HOME());

        uint256 supply = nft.totalSupply();

        console2.log("Current NFT supply: %s", supply);

        // Create unique proposal description
        uint256 randomNum = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 10_000;
        string memory description =
            string(abi.encodePacked("Add Francis as member - Proposal #", vm.toString(randomNum)));
        // bytes32 descriptionHash = keccak256(bytes(description));

        // STEP 1: CREATE PROPOSAL
        console2.log("\n=== STEP 1: CREATE PROPOSAL ===");
        console2.log("Creating proposal to add Francis as member");

        // Proposal parameters
        address[] memory targets = new address[](1);
        targets[0] = nftAddressChainA;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("safeMint(address,string)", francis, TOKEN_URI);

        // Log the proposal parameters in detail
        console2.log("Target contract address: %s", targets[0]);
        console2.log("Target is NFT contract: %s", targets[0] == nftAddressChainA ? "true" : "false");
        // console.log("Function signature: %s", bytes4(calldatas[0]));
        console2.log("Francis address: %s", francis);
        console2.log("Token URI: %s", TOKEN_URI);
        console2.log("Proposal description: %s", description);

        // Check NFT balance
        uint256 balance = nft.balanceOf(alice);
        console2.log("Alice's NFT balance: %s", balance);

        // Check delegation status
        try nft.delegates(alice) returns (address delegate) {
            console2.log("Alice has delegated to: %s", delegate);

            if (delegate == alice) {
                console2.log("Alice has self-delegated");
            } else if (delegate == address(0)) {
                console2.log("Alice has not delegated");
            } else {
                console2.log("Alice has delegated to another address");
            }
        } catch Error(string memory reason) {
            console2.log("Failed to check delegation: %s", reason);
        } catch {
            console2.log("Failed to check delegation (unknown error)");
        }

        console2.log("About to submit proposal...");

        // Create the proposal
        uint256 proposalId;
        vm.startBroadcast(aliceKey);
        try gov.propose(targets, values, calldatas, description) returns (uint256 _proposalId) {
            proposalId = _proposalId;
            console2.log("Proposal created successfully with ID: %s", proposalId);
            console2.log("Proposal ID (hex): 0x%x", proposalId);

            // Try to get additional details about the proposal
            try gov.proposalSnapshot(proposalId) returns (uint256 snapshot) {
                console2.log("Proposal snapshot block: %s", snapshot);
            } catch {
                console2.log("Could not retrieve proposal snapshot");
            }

            try gov.proposalDeadline(proposalId) returns (uint256 deadline) {
                console2.log("Proposal deadline block: %s", deadline);
            } catch {
                console2.log("Could not retrieve proposal deadline");
            }
        } catch Error(string memory reason) {
            console2.log("Failed to create proposal: %s", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console2.log("Failed to create proposal (unknown error)");
            // Try to provide more information about what went wrong
            console2.log("Current chain ID: %s", block.chainid);
            console2.log("Gov address: %s", address(gov));
            console2.log("Alice address: %s", alice);
            vm.stopBroadcast();
            return;
        }
        vm.stopBroadcast();

        // Display governance parameters
        console2.log("\nGovernance parameters:");
        console2.log("Voting delay: %s blocks", gov.votingDelay());
        console2.log("Voting period: %s blocks", gov.votingPeriod());

        // Get and display the proposal state
        try gov.state(proposalId) returns (IGovernor.ProposalState state) {
            console2.log("Current proposal state: %s", uint8(state));
            // 0: Pending, 1: Active, 2: Canceled, 3: Defeated, 4: Succeeded, 5: Queued, 6: Expired, 7: Executed
            string memory stateString;
            if (state == IGovernor.ProposalState.Pending) stateString = "Pending";
            else if (state == IGovernor.ProposalState.Active) stateString = "Active";
            else if (state == IGovernor.ProposalState.Canceled) stateString = "Canceled";
            else if (state == IGovernor.ProposalState.Defeated) stateString = "Defeated";
            else if (state == IGovernor.ProposalState.Succeeded) stateString = "Succeeded";
            else if (state == IGovernor.ProposalState.Queued) stateString = "Queued";
            else if (state == IGovernor.ProposalState.Expired) stateString = "Expired";
            else if (state == IGovernor.ProposalState.Executed) stateString = "Executed";
            console2.log("Proposal state: %s", stateString);
        } catch Error(string memory reason) {
            console2.log("Failed to get proposal state: %s", reason);
        } catch {
            console2.log("Failed to get proposal state (unknown error)");
        }
    }
}
