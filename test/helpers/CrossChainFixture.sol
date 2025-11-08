// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { BaseTest } from "./BaseTest.sol";
import { NFT } from "../../src/NFT.sol";
import { Gov } from "../../src/Gov.sol";
import { console } from "forge-std/src/console.sol";

/**
 * @title CrossChainFixture
 * @notice Helper contract for setting up cross-chain test scenarios
 * @dev Manages deployments across multiple chains for testing
 */
abstract contract CrossChainFixture is BaseTest {
    /*//////////////////////////////////////////////////////////////
                            STRUCTURES
    //////////////////////////////////////////////////////////////*/

    struct ChainDeployment {
        NFT nft;
        Gov gov;
        uint256 chainId;
        string name;
    }

    /*//////////////////////////////////////////////////////////////
                        CHAIN DEPLOYMENTS
    //////////////////////////////////////////////////////////////*/

    ChainDeployment public optimism;
    ChainDeployment public arbitrum;
    ChainDeployment public base;

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT PARAMETERS
    //////////////////////////////////////////////////////////////*/

    string internal constant DEFAULT_NFT_NAME = "DAO Membership";
    string internal constant DEFAULT_NFT_SYMBOL = "DAOM";
    string internal constant DEFAULT_NFT_URI = "ipfs://QmTokenURI";
    string internal constant DEFAULT_GOV_NAME = "Cross-Chain DAO";
    string internal constant DEFAULT_MANIFESTO = "QmInitialManifestoCID";

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys contracts on the home chain (Optimism)
     * @param initialMembers Array of initial member addresses
     * @return deployment The deployment struct with contract addresses
     */
    function deployHomeChain(address[] memory initialMembers) internal returns (ChainDeployment memory) {
        return deployOnChain(OPTIMISM, OPTIMISM, initialMembers, "Optimism");
    }

    /**
     * @notice Deploys contracts on a foreign chain
     * @param chainId The chain ID to deploy on
     * @param homeChainId The home chain ID
     * @param initialMembers Array of initial member addresses
     * @param chainName Name of the chain for logging
     * @return deployment The deployment struct with contract addresses
     */
    function deployOnChain(
        uint256 chainId,
        uint256 homeChainId,
        address[] memory initialMembers,
        string memory chainName
    )
        internal
        returns (ChainDeployment memory deployment)
    {
        vm.chainId(chainId);
        console.log("Deploying on", chainName, "- Chain ID:", block.chainid);

        vm.startPrank(deployer);

        // Deploy NFT contract
        NFT nft = new NFT(homeChainId, deployer, initialMembers, DEFAULT_NFT_URI, DEFAULT_NFT_NAME, DEFAULT_NFT_SYMBOL);

        console.log(chainName, "- NFT deployed at:", address(nft));

        // Deploy governance contract
        Gov gov = new Gov(
            homeChainId,
            nft,
            DEFAULT_MANIFESTO,
            DEFAULT_GOV_NAME,
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        console.log(chainName, "- Gov deployed at:", address(gov));

        // Transfer NFT ownership to governance contract
        nft.transferOwnership(address(gov));
        console.log(chainName, "- NFT ownership transferred to Gov");

        vm.stopPrank();

        deployment = ChainDeployment({ nft: nft, gov: gov, chainId: chainId, name: chainName });

        labelContracts(address(gov), address(nft));
    }

    /**
     * @notice Deploys contracts on a foreign chain with custom parameters
     * @param chainId The chain ID to deploy on
     * @param homeChainId The home chain ID
     * @param initialMembers Array of initial member addresses
     * @param nftName NFT collection name
     * @param nftSymbol NFT collection symbol
     * @param nftUri Initial NFT token URI
     * @param govName Governance contract name
     * @param manifesto Initial manifesto CID
     * @return deployment The deployment struct with contract addresses
     */
    function deployOnChainCustom(
        uint256 chainId,
        uint256 homeChainId,
        address[] memory initialMembers,
        string memory nftName,
        string memory nftSymbol,
        string memory nftUri,
        string memory govName,
        string memory manifesto
    )
        internal
        returns (ChainDeployment memory deployment)
    {
        vm.chainId(chainId);

        vm.startPrank(deployer);

        NFT nft = new NFT(homeChainId, deployer, initialMembers, nftUri, nftName, nftSymbol);

        Gov gov = new Gov(
            homeChainId,
            nft,
            manifesto,
            govName,
            DEFAULT_VOTING_DELAY,
            DEFAULT_VOTING_PERIOD,
            DEFAULT_PROPOSAL_THRESHOLD,
            DEFAULT_QUORUM_NUMERATOR
        );

        nft.transferOwnership(address(gov));

        vm.stopPrank();

        deployment = ChainDeployment({ nft: nft, gov: gov, chainId: chainId, name: "Custom" });
    }

    /**
     * @notice Sets up standard two-chain deployment (Optimism + Arbitrum)
     * @param memberCount Number of initial members
     */
    function setUpTwoChainDeployment(uint256 memberCount) internal {
        address[] memory members = createInitialMembers(memberCount);

        // Deploy on Optimism (home chain)
        optimism = deployHomeChain(members);

        // Deploy on Arbitrum (foreign chain)
        arbitrum = deployOnChain(ARBITRUM, OPTIMISM, members, "Arbitrum");
    }

    /**
     * @notice Sets up three-chain deployment (Optimism + Arbitrum + Base)
     * @param memberCount Number of initial members
     */
    function setUpThreeChainDeployment(uint256 memberCount) internal {
        address[] memory members = createInitialMembers(memberCount);

        // Deploy on all chains
        optimism = deployHomeChain(members);
        arbitrum = deployOnChain(ARBITRUM, OPTIMISM, members, "Arbitrum");
        base = deployOnChain(BASE, OPTIMISM, members, "Base");
    }

    /*//////////////////////////////////////////////////////////////
                        CHAIN SWITCHING HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Switches to a specific chain deployment
     * @param deployment The chain deployment to switch to
     */
    function switchToChain(ChainDeployment memory deployment) internal {
        vm.chainId(deployment.chainId);
    }

    /**
     * @notice Switches to Optimism chain
     */
    function switchToOptimism() internal {
        vm.chainId(optimism.chainId);
    }

    /**
     * @notice Switches to Arbitrum chain
     */
    function switchToArbitrum() internal {
        vm.chainId(arbitrum.chainId);
    }

    /**
     * @notice Switches to Base chain
     */
    function switchToBase() internal {
        vm.chainId(base.chainId);
    }

    /*//////////////////////////////////////////////////////////////
                        DELEGATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets up self-delegation for all initial members on a chain
     * @param deployment The chain deployment
     */
    function setupSelfDelegation(ChainDeployment memory deployment) internal {
        switchToChain(deployment);

        uint256 totalSupply = deployment.nft.totalSupply();
        for (uint256 i = 0; i < totalSupply; i++) {
            address member = deployment.nft.ownerOf(i);
            vm.prank(member);
            deployment.nft.delegate(member);
        }

        // Advance block to activate delegations
        advanceBlocks(1);
    }

    /*//////////////////////////////////////////////////////////////
                        VERIFICATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies deployment state is correct
     * @param deployment The deployment to verify
     * @param expectedMemberCount Expected number of members
     */
    function verifyDeploymentState(ChainDeployment memory deployment, uint256 expectedMemberCount) internal {
        switchToChain(deployment);

        // Verify NFT state
        assertEq(deployment.nft.totalSupply(), expectedMemberCount, "Incorrect total supply");
        assertEq(deployment.nft.owner(), address(deployment.gov), "Gov not owner of NFT");
        assertEq(deployment.nft.HOME(), OPTIMISM, "Incorrect home chain");

        // Verify Gov state
        assertEq(deployment.gov.HOME(), OPTIMISM, "Incorrect gov home chain");
        assertNotEmptyString(deployment.gov.manifesto(), "Empty manifesto");
    }
}
