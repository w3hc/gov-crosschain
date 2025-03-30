// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console } from "forge-std/src/Test.sol";
import { Script } from "forge-std/src/Script.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

/**
 * @title OneStepProposal
 * @notice Creates, votes on, and executes a proposal in one script
 */
contract OneStepProposal is Script {
    // Contract addresses
    address public GOV_ADDRESS_CHAIN_A = 0x0d78593C69cE360DC245C44414f3f491F8669206;
    address public NFT_ADDRESS_CHAIN_A = 0x5c8d756032b4511cCfc57BA14f0DBFE70632A3Cc;
    address public GOV_ADDRESS_CHAIN_B = 0x0d78593C69cE360DC245C44414f3f491F8669206;
    address public NFT_ADDRESS_CHAIN_B = 0x5c8d756032b4511cCfc57BA14f0DBFE70632A3Cc;

    // Chain IDs
    uint256 public CHAIN_A_ID = 901; // OPChainA
    uint256 public CHAIN_B_ID = 902; // OPChainB

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

    // Important: This function is executed on the test environment, not the actual blockchain
    // It's important to understand that chain ID modifications only affect local execution,
    // not the actual transactions that get broadcasted
    function run() public {
        console.log("=== CROSS-CHAIN DAO MEMBERSHIP PROPOSAL ===");
        console.log("Current chain ID: %s", block.chainid);

        // IMPORTANT: In Forge script with --broadcast, vm.chainId() only affects the local execution environment
        // and doesn't change the actual blockchain we're interacting with. For this to work correctly,
        // we need to modify the contracts to accept the current chain as the home chain during testing

        // Get contract instances
        Gov gov = Gov(payable(GOV_ADDRESS_CHAIN_A));

        // Create unique proposal description
        uint256 randomNum = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 10_000;
        string memory description =
            string(abi.encodePacked("Add Francis as member - Proposal #", vm.toString(randomNum)));

        // STEP 1: CREATE PROPOSAL
        console.log("\n=== STEP 1: CREATE PROPOSAL ===");
        console.log("Creating proposal to add Francis as member");

        // Proposal parameters
        address[] memory targets = new address[](1);
        targets[0] = NFT_ADDRESS_CHAIN_A;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("safeMint(address,string)", francis, TOKEN_URI);

        console.log("Proposal description: %s", description);

        // Create the proposal
        uint256 proposalId;
        vm.startBroadcast(aliceKey);
        try gov.propose(targets, values, calldatas, description) returns (uint256 _proposalId) {
            proposalId = _proposalId;
            console.log("Proposal created successfully with ID: %s", proposalId);
            console.log("Proposal ID (hex): 0x%x", proposalId);
        } catch Error(string memory reason) {
            console.log("Failed to create proposal: %s", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Failed to create proposal (unknown error)");
            vm.stopBroadcast();
            return;
        }
        vm.stopBroadcast();

        // Display governance parameters
        console.log("\nGovernance parameters:");
        console.log("Voting delay: %s blocks", gov.votingDelay());
        console.log("Voting period: %s blocks", gov.votingPeriod());

        // Get and display the proposal state
        try gov.state(proposalId) returns (IGovernor.ProposalState state) {
            console.log("Current proposal state: %s", uint8(state));
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
            console.log("Proposal state: %s", stateString);
        } catch {
            console.log("Failed to get proposal state");
        }
    }
}
