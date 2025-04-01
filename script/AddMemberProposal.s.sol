// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { Gov } from "../src/Gov.sol";
import { NFT } from "../src/NFT.sol";

/**
 * @title AddMemberProposal
 * @notice Creates a proposal to add Francis as member with inline cross-chain claim
 */
contract AddMemberProposal is Script {
    // Contract addresses - same on all chains due to deterministic deployment
    address public govAddress = 0x29097565C61A9e72a78Cc7F34bC9eBf7E17949c9;
    address public nftAddress = 0x725236fbb802Dab972875835dB7c2bF706A9e7eB;

    // Account addresses
    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bob = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public francis = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    // Private keys
    uint256 public aliceKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // Token URI
    string public constant TOKEN_URI = "ipfs://QmFrancisTokenURI";

    function run() public {
        // Get contract instances on Optimism
        Gov gov = Gov(payable(govAddress));
        NFT nft = NFT(nftAddress);

        console2.log("Optimism Chain");
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

        // Step 1: Ensure Alice has delegated voting power to herself
        vm.startBroadcast(aliceKey);
        nft.delegate(alice);
        vm.stopBroadcast();

        console2.log("Alice has delegated voting power to herself");

        // Step 2: Create the proposal
        vm.startBroadcast(aliceKey);
        uint256 proposalId = gov.propose(targets, values, calldatas, description);
        vm.stopBroadcast();

        console2.log("Proposal created with ID: %s", proposalId);
        console2.log("Proposal description: %s", description);

        string memory hexString = vm.toString(bytes32(descHash));
        console2.log("Description hash: %s", hexString);

        // Get the current proposal state
        uint8 state = uint8(gov.state(proposalId));
        string memory stateStr;
        if (state == 0) stateStr = "Pending";
        else if (state == 1) stateStr = "Active";
        else if (state == 2) stateStr = "Canceled";
        else if (state == 3) stateStr = "Defeated";
        else if (state == 4) stateStr = "Succeeded";
        else if (state == 5) stateStr = "Queued";
        else if (state == 6) stateStr = "Expired";
        else if (state == 7) stateStr = "Executed";

        console2.log("Current proposal state: %s (%d)", stateStr, state);

        // Dynamically determine the expected token ID based on total supply
        uint256 expectedTokenId = nft.totalSupply();
        console2.log("Current NFT total supply: %d", expectedTokenId);
        console2.log("Expected token ID for Francis: %d", expectedTokenId);

        // Generate the cross-chain proof in advance
        bytes memory crossChainProof = generateCrossChainProof(
            nftAddress, // Same address on both chains
            expectedTokenId,
            francis,
            TOKEN_URI
        );

        string memory proofHex = vm.toString(crossChainProof);

        console2.log("\nNext steps:");

        if (state == 0) {
            console2.log("1. Wait for the voting delay to pass (current delay: %s blocks)", gov.votingDelay());
        }

        if (state == 0 || state == 1) {
            // Using string.concat for Alice's vote command
            string memory aliceVoteCmd = string.concat(
                "cast send --rpc-url op --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 ",
                vm.toString(govAddress),
                " \"castVote(uint256,uint8)\" ",
                vm.toString(proposalId),
                " 1"
            );
            console2.log("2. Have Alice vote on the proposal with this command:");
            console2.log("%s", aliceVoteCmd);

            // Using string.concat for Bob's vote command
            string memory bobVoteCmd = string.concat(
                "cast send --rpc-url op --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d ",
                vm.toString(govAddress),
                " \"castVote(uint256,uint8)\" ",
                vm.toString(proposalId),
                " 1"
            );
            console2.log("\n3. Have Bob vote with this command:");
            console2.log("%s", bobVoteCmd);

            console2.log("\n4. Wait for the voting period to end (%s blocks)", gov.votingPeriod());
        }

        if (state < 7) {
            // Using string.concat for execute command
            string memory executeCmd = string.concat(
                "cast send --rpc-url op --private-key 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a ",
                vm.toString(govAddress),
                " \"execute(address[],uint256[],bytes[],bytes32)\" \"[",
                vm.toString(nftAddress),
                "]\" \"[0]\" \"[0xd204c45e0000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000018697066733a2f2f516d4672616e636973546f6b656e5552490000000000000000]\" ",
                hexString
            );

            console2.log("\n5. Execute the proposal with this command:");
            console2.log("%s", executeCmd);
        }

        // After the proposal executes
        console2.log("\n=== CROSS-CHAIN STEPS ===");

        // 1. Verify the NFT was minted on Optimism
        string memory verifyOwnerCmd = string.concat(
            "cast call --rpc-url op ", vm.toString(nftAddress), " \"ownerOf(uint256)\" ", vm.toString(expectedTokenId)
        );
        console2.log("1. Verify Francis owns NFT on Optimism with this command:");
        console2.log("%s", verifyOwnerCmd);

        // 2. Verify contracts on Base
        string memory verifyInterfaceCmd = string.concat(
            "cast call --rpc-url base ", vm.toString(nftAddress), " \"supportsInterface(bytes4)\" 0x80ac58cd"
        );
        console2.log("\n2. Verify Base chain contracts are working:");
        console2.log("%s", verifyInterfaceCmd);

        string memory verifyManifestoCmd =
            string.concat("cast call --rpc-url base ", vm.toString(govAddress), " \"manifesto()\"");
        console2.log("%s", verifyManifestoCmd);

        // 3. Generate mint proof command (added as requested)
        string memory generateMintProofCmd = string.concat(
            "cast call --rpc-url op ",
            vm.toString(nftAddress),
            " \"generateMintProof(uint256)\" ",
            vm.toString(expectedTokenId)
        );
        console2.log("\n3. Generate mint proof from Optimism with this command:");
        console2.log("%s", generateMintProofCmd);

        // 4. Claim using the pre-generated proof
        string memory claimMintCmd = string.concat(
            "cast send --rpc-url base --private-key 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a ",
            vm.toString(nftAddress),
            " \"claimMint(bytes)\" ",
            proofHex
        );
        console2.log("\n4. Claim membership on Base with this command:");
        console2.log("%s", claimMintCmd);

        // 5. Verify the membership on Base
        string memory verifyBalanceCmd = string.concat(
            "cast call --rpc-url base ", vm.toString(nftAddress), " \"balanceOf(address)\" ", vm.toString(francis)
        );
        console2.log("\n5. Verify Francis owns the NFT on Base with this command:");
        console2.log("%s", verifyBalanceCmd);
    }

    /**
     * @notice Generates a cross-chain proof for membership claim
     * @param targetNFTAddress The NFT contract address on the target chain
     * @param tokenId The token ID to claim
     * @param tokenOwner The address that should receive the token
     * @param tokenURI The token URI to set
     * @return bytes The encoded proof ready for cross-chain claim
     */
    function generateCrossChainProof(
        address targetNFTAddress,
        uint256 tokenId,
        address tokenOwner,
        string memory tokenURI
    )
        public
        pure
        returns (bytes memory)
    {
        // Create the message with the TARGET contract address
        bytes32 message = keccak256(
            abi.encodePacked(
                targetNFTAddress, // Target contract address
                uint8(0), // MINT operation (matches enum in NFT.sol)
                tokenId,
                tokenOwner,
                tokenURI
            )
        );

        // Create the digest using Ethereum signed message format
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        // Return encoded proof in the format expected by claimMint
        return abi.encode(tokenId, tokenOwner, tokenURI, digest);
    }
}
