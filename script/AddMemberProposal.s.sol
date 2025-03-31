// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";

/**
 * @title AddMemberProposal
 * @notice Creates a proposal to add Francis as member
 */
contract AddMemberProposal is Script {
    // Contract addresses
    address public govAddress = 0x8bf83bE8F050AB75a2418B89eeA3D4262beBAFE3;
    address public nftAddress = 0xF71F50CD291BEfABE178e1A75112Ef6d051B5824;

    // Account addresses
    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public francis = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    // Private keys
    uint256 public aliceKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // Token URI
    string public constant TOKEN_URI = "ipfs://QmFrancisTokenURI";

    function run() public {
        // Get contract instances
        Gov gov = Gov(payable(govAddress));
        NFT nft = NFT(nftAddress);

        console2.log("Gov contract address: %s", address(gov));
        console2.log("NFT contract address: %s", address(nft));

        // Create proposal to add Francis
        address[] memory targets = new address[](1);
        targets[0] = nftAddress;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("safeMint(address,string)", francis, TOKEN_URI);

        uint256 randomNum = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 10_000;
        string memory description =
            string(abi.encodePacked("Add Francis as member - Proposal #", vm.toString(randomNum)));
        bytes32 descHash = keccak256(bytes(description));

        console2.log("\n=== CREATING PROPOSAL ===");
        console2.log("This will create a proposal to add Francis as a member");

        // Start broadcast for proposal creation
        vm.startBroadcast(aliceKey);
        uint256 proposalId = gov.propose(targets, values, calldatas, description);
        vm.stopBroadcast();

        console2.log("Proposal created with ID: %s", proposalId);
        console2.log("Proposal description: %s", description);

        string memory hexString = vm.toString(bytes32(descHash));
        console2.log("Description hash: %s", hexString);

        console2.log("\nNext steps:");
        console2.log("1. Wait for the voting delay (%s blocks) to pass", gov.votingDelay());
        console2.log("2. Have Alice and Bob vote on the proposal");
        console2.log("3. Wait for the voting period (%s blocks) to end", gov.votingPeriod());
        console2.log("4. Have Francis execute the proposal");

        console2.log("\nCommands for voting and execution:");
        console2.log("# Alice votes");
        console2.log(
            "cast send --rpc-url http://127.0.0.1:9545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 0x8bf83bE8F050AB75a2418B89eeA3D4262beBAFE3 \"castVote(uint256,uint8)\" %s 1",
            proposalId
        );

        console2.log("\n# Bob votes");
        console2.log(
            "cast send --rpc-url http://127.0.0.1:9545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d 0x8bf83bE8F050AB75a2418B89eeA3D4262beBAFE3 \"castVote(uint256,uint8)\" %s 1",
            proposalId
        );

        // bytes memory calldata0 = calldatas[0];
        // string memory calldata0Str = vm.toString(calldata0);

        console2.log("\n# Francis executes");
        console2.log(
            "cast send --rpc-url http://127.0.0.1:9545 --private-key 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a 0x8bf83bE8F050AB75a2418B89eeA3D4262beBAFE3 \"execute(address[],uint256[],bytes[],bytes32)\" \"[0xF71F50CD291BEfABE178e1A75112Ef6d051B5824]\" \"[0]\" \"[0xd204c45e0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000018697066733a2f2f516d4672616e636973546f6b656e5552490000000000000000]\" %s",
            hexString
        );

        // Add verification and cross-chain commands
        console2.log("\n# Verify Francis owns NFT with ID 2");
        console2.log(
            "cast call --rpc-url http://127.0.0.1:9545 0xF71F50CD291BEfABE178e1A75112Ef6d051B5824 \"ownerOf(uint256)\" 2"
        );

        console2.log("\n# Generate proof for cross-chain membership");
        console2.log(
            "cast call --rpc-url http://127.0.0.1:9545 0xF71F50CD291BEfABE178e1A75112Ef6d051B5824 \"generateMintProof(uint256)\" 2"
        );

        console2.log("\n# Claim membership on Chain B (OPChainB)");
        console2.log(
            "cast send --rpc-url http://127.0.0.1:9546 --private-key 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a 0xF71F50CD291BEfABE178e1A75112Ef6d051B5824 \"claimMint(bytes)\" <PROOF_FROM_PREVIOUS_STEP>"
        );
    }
}
