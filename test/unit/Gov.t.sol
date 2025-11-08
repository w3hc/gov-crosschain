// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { BaseTest } from "../helpers/BaseTest.sol";
import { ProofHelper } from "../helpers/ProofHelper.sol";
import { Gov } from "../../src/Gov.sol";
import { NFT } from "../../src/NFT.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

/**
 * @title GovTest
 * @notice Comprehensive unit tests for the Gov contract
 */
contract GovTest is BaseTest {
    NFT public nft;
    Gov public gov;

    // Proposal variables
    address[] public proposalTargets;
    uint256[] public proposalValues;
    bytes[] public proposalCalldatas;
    string public proposalDescription;

    function setUp() public {
        setUpAccounts();
        vm.chainId(OPTIMISM);

        vm.startPrank(deployer);

        // Create initial members
        address[] memory initialMembers = createInitialMembers(2);

        // Deploy NFT
        nft = new NFT(OPTIMISM, deployer, initialMembers, "ipfs://QmTokenURI", "DAO Membership", "DAOM");

        // Deploy governance
        gov = new Gov(
            OPTIMISM,
            nft,
            "QmInitialManifestoCID",
            "Cross-Chain DAO",
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
        assertEq(gov.name(), "Cross-Chain DAO");
        assertEq(gov.HOME(), OPTIMISM);
        assertEq(gov.manifesto(), "QmInitialManifestoCID");
        assertEq(gov.votingDelay(), DEFAULT_VOTING_DELAY);
        assertEq(gov.votingPeriod(), DEFAULT_VOTING_PERIOD);
        assertEq(gov.proposalThreshold(), DEFAULT_PROPOSAL_THRESHOLD);
    }

    function test_constructor_SetsCorrectToken() public view {
        assertEq(address(gov.token()), address(nft));
    }

    /*//////////////////////////////////////////////////////////////
                    MANIFESTO UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setManifesto_UpdatesManifestoSuccessfully() public onHomeChain {
        string memory newManifesto = "QmNewManifestoCID";

        vm.expectEmit(true, true, false, true);
        emit Gov.ManifestoUpdated("QmInitialManifestoCID", newManifesto);

        vm.prank(address(gov));
        gov.setManifesto(newManifesto);

        assertEq(gov.manifesto(), newManifesto);
    }

    function test_setManifesto_RevertsWhen_CalledByNonGovernance() public onHomeChain asUser(alice) {
        vm.expectRevert();
        gov.setManifesto("QmNewManifestoCID");
    }

    function test_setManifesto_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);

        vm.prank(address(gov));
        vm.expectRevert(Gov.OnlyHomeChainAllowed.selector);
        gov.setManifesto("QmNewManifestoCID");
    }

    /*//////////////////////////////////////////////////////////////
                    VOTING DELAY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setVotingDelay_UpdatesDelaySuccessfully() public onHomeChain {
        uint48 newDelay = 200;
        uint256 oldDelay = gov.votingDelay();

        vm.expectEmit(true, false, false, true);
        emit Gov.GovernanceParameterUpdated(Gov.OperationType.UPDATE_VOTING_DELAY, oldDelay, newDelay);

        vm.prank(address(gov));
        gov.setVotingDelay(newDelay);

        assertEq(gov.votingDelay(), newDelay);
    }

    function test_setVotingDelay_RevertsWhen_CalledByNonGovernance() public onHomeChain asUser(alice) {
        vm.expectRevert();
        gov.setVotingDelay(200);
    }

    function test_setVotingDelay_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);

        vm.prank(address(gov));
        vm.expectRevert(Gov.OnlyHomeChainAllowed.selector);
        gov.setVotingDelay(200);
    }

    /*//////////////////////////////////////////////////////////////
                    VOTING PERIOD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setVotingPeriod_UpdatesPeriodSuccessfully() public onHomeChain {
        uint32 newPeriod = 1000;
        uint256 oldPeriod = gov.votingPeriod();

        vm.expectEmit(true, false, false, true);
        emit Gov.GovernanceParameterUpdated(Gov.OperationType.UPDATE_VOTING_PERIOD, oldPeriod, newPeriod);

        vm.prank(address(gov));
        gov.setVotingPeriod(newPeriod);

        assertEq(gov.votingPeriod(), newPeriod);
    }

    function test_setVotingPeriod_RevertsWhen_CalledByNonGovernance() public onHomeChain asUser(alice) {
        vm.expectRevert();
        gov.setVotingPeriod(1000);
    }

    function test_setVotingPeriod_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);

        vm.prank(address(gov));
        vm.expectRevert(Gov.OnlyHomeChainAllowed.selector);
        gov.setVotingPeriod(1000);
    }

    /*//////////////////////////////////////////////////////////////
                PROPOSAL THRESHOLD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setProposalThreshold_UpdatesThresholdSuccessfully() public onHomeChain {
        uint256 newThreshold = 5;
        uint256 oldThreshold = gov.proposalThreshold();

        vm.expectEmit(true, false, false, true);
        emit Gov.GovernanceParameterUpdated(Gov.OperationType.UPDATE_PROPOSAL_THRESHOLD, oldThreshold, newThreshold);

        vm.prank(address(gov));
        gov.setProposalThreshold(newThreshold);

        assertEq(gov.proposalThreshold(), newThreshold);
    }

    function test_setProposalThreshold_RevertsWhen_CalledByNonGovernance() public onHomeChain asUser(alice) {
        vm.expectRevert();
        gov.setProposalThreshold(5);
    }

    function test_setProposalThreshold_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);

        vm.prank(address(gov));
        vm.expectRevert(Gov.OnlyHomeChainAllowed.selector);
        gov.setProposalThreshold(5);
    }

    /*//////////////////////////////////////////////////////////////
                    QUORUM UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_updateQuorumNumerator_UpdatesQuorumSuccessfully() public onHomeChain {
        uint256 newQuorum = 10;
        uint256 oldQuorum = gov.quorumNumerator();

        vm.expectEmit(true, false, false, true);
        emit Gov.GovernanceParameterUpdated(Gov.OperationType.UPDATE_QUORUM, oldQuorum, newQuorum);

        vm.prank(address(gov));
        gov.updateQuorumNumerator(newQuorum);

        assertEq(gov.quorumNumerator(), newQuorum);
    }

    function test_updateQuorumNumerator_RevertsWhen_CalledByNonGovernance() public onHomeChain asUser(alice) {
        vm.expectRevert();
        gov.updateQuorumNumerator(10);
    }

    function test_updateQuorumNumerator_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);

        vm.prank(address(gov));
        vm.expectRevert(Gov.OnlyHomeChainAllowed.selector);
        gov.updateQuorumNumerator(10);
    }

    /*//////////////////////////////////////////////////////////////
                    PROPOSAL CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_propose_CreatesProposalSuccessfully() public onHomeChain {
        // Setup delegation
        vm.prank(alice);
        nft.delegate(alice);
        advanceBlocks(1);

        // Create proposal
        _setupBasicProposal();

        vm.prank(alice);
        uint256 proposalId = gov.propose(proposalTargets, proposalValues, proposalCalldatas, proposalDescription);

        assertGt(proposalId, 0);
        assertEq(uint8(gov.state(proposalId)), uint8(IGovernor.ProposalState.Pending));
    }

    function test_propose_TracksProposalId() public onHomeChain {
        // Setup delegation
        vm.prank(alice);
        nft.delegate(alice);
        advanceBlocks(1);

        // Create proposal
        _setupBasicProposal();

        vm.prank(alice);
        uint256 proposalId = gov.propose(proposalTargets, proposalValues, proposalCalldatas, proposalDescription);

        assertEq(gov.proposalIds(0), proposalId);
    }

    function test_propose_RevertsWhen_BelowThreshold() public onHomeChain {
        // Set threshold higher than alice's votes
        vm.prank(address(gov));
        gov.setProposalThreshold(5);

        // Setup delegation
        vm.prank(alice);
        nft.delegate(alice);
        advanceBlocks(1);

        // Try to create proposal
        _setupBasicProposal();

        vm.prank(alice);
        vm.expectRevert();
        gov.propose(proposalTargets, proposalValues, proposalCalldatas, proposalDescription);
    }

    /*//////////////////////////////////////////////////////////////
                    PROOF GENERATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_generateManifestoProof_GeneratesValidProof() public onHomeChain {
        string memory newManifesto = "QmNewManifestoCID";

        bytes memory proof = gov.generateManifestoProof(newManifesto);

        assertGt(proof.length, 0);
    }

    function test_generateManifestoProof_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);

        vm.expectRevert(Gov.ProofsOnlyOnHomeChain.selector);
        gov.generateManifestoProof("QmNewManifestoCID");
    }

    function test_generateParameterProof_GeneratesValidProof() public onHomeChain {
        bytes memory valueBytes = abi.encodePacked(uint48(200));

        bytes memory proof = gov.generateParameterProof(Gov.OperationType.UPDATE_VOTING_DELAY, valueBytes);

        assertGt(proof.length, 0);
    }

    function test_generateParameterProof_RevertsWhen_OnForeignChain() public {
        vm.chainId(ARBITRUM);
        bytes memory valueBytes = abi.encodePacked(uint48(200));

        vm.expectRevert(Gov.ProofsOnlyOnHomeChain.selector);
        gov.generateParameterProof(Gov.OperationType.UPDATE_VOTING_DELAY, valueBytes);
    }

    /*//////////////////////////////////////////////////////////////
                    QUORUM CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_quorum_HasCorrectNumerator() public view {
        // Verify quorum numerator is set correctly
        assertEq(gov.quorumNumerator(), DEFAULT_QUORUM_NUMERATOR);
    }

    function test_quorum_NumeratorUpdates() public onHomeChain {
        uint256 initialNumerator = gov.quorumNumerator();
        assertEq(initialNumerator, DEFAULT_QUORUM_NUMERATOR);

        // Update quorum to 50%
        uint256 newQuorum = 50;
        vm.prank(address(gov));
        gov.updateQuorumNumerator(newQuorum);

        // Verify numerator updated
        assertEq(gov.quorumNumerator(), newQuorum, "Quorum numerator should update");
        assertTrue(gov.quorumNumerator() > initialNumerator, "New quorum should be higher");
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupBasicProposal() internal {
        proposalTargets = new address[](1);
        proposalTargets[0] = address(gov);

        proposalValues = new uint256[](1);
        proposalValues[0] = 0;

        proposalCalldatas = new bytes[](1);
        proposalCalldatas[0] = abi.encodeWithSignature("setManifesto(string)", "QmNewManifestoCID");

        proposalDescription = "Update manifesto to new version";
    }
}
