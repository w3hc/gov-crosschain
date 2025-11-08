// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorVotes, IVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovProposalTracking } from "./extensions/GovProposalTracking.sol";
import { GovSponsor } from "./extensions/GovSponsor.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Gov
 * @author W3HC
 * @notice Implementation of a DAO with cross-chain synchronization capabilities
 * @dev Extends OpenZeppelin's Governor contract with cross-chain parameter updates
 * @custom:security-contact julien@strat.cc
 */
contract Gov is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovProposalTracking,
    GovSponsor
{
    /// @notice Chain ID where this contract was originally deployed
    uint256 public immutable HOME;

    /// @notice IPFS CID of the DAO's manifesto
    string public manifesto;

    /// @notice Emitted when the manifesto is updated
    /// @param oldManifesto Previous manifesto CID
    /// @param newManifesto New manifesto CID
    event ManifestoUpdated(string oldManifesto, string newManifesto);

    /// @notice Types of operations that can be synchronized across chains
    enum OperationType {
        SET_MANIFESTO,
        UPDATE_VOTING_DELAY,
        UPDATE_VOTING_PERIOD,
        UPDATE_PROPOSAL_THRESHOLD,
        UPDATE_QUORUM
    }

    /// @notice Emitted when a governance parameter is updated
    /// @param operationType Type of parameter that was updated
    /// @param oldValue Previous value of the parameter
    /// @param newValue New value of the parameter
    event GovernanceParameterUpdated(OperationType indexed operationType, uint256 oldValue, uint256 newValue);

    // Custom errors
    /// @notice Error thrown when an operation is attempted on a foreign chain that should only happen on home chain
    error OnlyHomeChainAllowed();

    /// @notice Error thrown when attempting to generate proofs from a foreign chain
    error ProofsOnlyOnHomeChain();

    /// @notice Error thrown when an invalid parameter proof is submitted
    error InvalidParameterProof();

    /// @notice Error thrown when an invalid manifesto proof is submitted
    error InvalidManifestoProof();

    /**
     * @notice Restricts functions to be called only on the home chain
     */
    modifier onlyHomeChain() {
        if (block.chainid != HOME) revert OnlyHomeChainAllowed();
        _;
    }

    /**
     * @notice Initializes the governance contract
     * @dev Sets up initial governance parameters and manifesto
     * @param _home Chain ID where this contract is considered home
     * @param _token The voting token contract address
     * @param _manifestoCid Initial manifesto CID
     * @param _name Name of the governance contract
     * @param _votingDelay Time before voting begins
     * @param _votingPeriod Duration of voting period
     * @param _proposalThreshold Minimum votes needed to create a proposal
     * @param _quorum Minimum participation percentage required
     */
    constructor(
        uint256 _home,
        IVotes _token,
        string memory _manifestoCid,
        string memory _name,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    )
        Governor(_name)
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorum)
    {
        HOME = _home;
        manifesto = _manifestoCid;

        // Initialize sponsorship extension
        // Cast IVotes to IERC721 since the membership token implements both
        _initializeGovSponsor(IERC721(address(_token)));
    }

    /**
     * @notice Updates the DAO's manifesto
     * @dev Can only be called through governance on home chain
     * @param newManifesto New manifesto CID
     */
    function setManifesto(string memory newManifesto) public onlyGovernance onlyHomeChain {
        string memory oldManifesto = manifesto;
        manifesto = newManifesto;
        emit ManifestoUpdated(oldManifesto, newManifesto);
    }

    /**
     * @notice Generates proof for cross-chain manifesto update
     * @dev Can only be called on home chain
     * @param newManifesto New manifesto CID to generate proof for
     * @return Encoded proof data for manifesto update
     */
    function generateManifestoProof(string memory newManifesto) external view returns (bytes memory) {
        if (block.chainid != HOME) revert ProofsOnlyOnHomeChain();
        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.SET_MANIFESTO), newManifesto));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return abi.encode(newManifesto, digest);
    }

    /**
     * @notice Claims a manifesto update on a foreign chain
     * @dev Verifies and applies manifesto updates from home chain
     * @param proof Proof generated by home chain
     */
    function claimManifestoUpdate(bytes memory proof) external {
        (string memory newManifesto, bytes32 digest) = abi.decode(proof, (string, bytes32));

        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.SET_MANIFESTO), newManifesto));
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        if (digest != expectedDigest) revert InvalidManifestoProof();

        string memory oldManifesto = manifesto;
        manifesto = newManifesto;
        emit ManifestoUpdated(oldManifesto, newManifesto);
    }

    /**
     * @notice Updates the voting delay parameter
     * @dev Can only be called through governance on home chain
     * @param newVotingDelay New voting delay value (in blocks)
     */
    function setVotingDelay(uint48 newVotingDelay) public virtual override onlyGovernance onlyHomeChain {
        uint256 oldValue = votingDelay();
        _setVotingDelay(newVotingDelay);
        emit GovernanceParameterUpdated(OperationType.UPDATE_VOTING_DELAY, oldValue, newVotingDelay);
    }

    /**
     * @notice Updates the voting period parameter
     * @dev Can only be called through governance on home chain
     * @param newVotingPeriod New voting period value (in blocks)
     */
    function setVotingPeriod(uint32 newVotingPeriod) public virtual override onlyGovernance onlyHomeChain {
        uint256 oldValue = votingPeriod();
        _setVotingPeriod(newVotingPeriod);
        emit GovernanceParameterUpdated(OperationType.UPDATE_VOTING_PERIOD, oldValue, newVotingPeriod);
    }

    /**
     * @notice Updates the proposal threshold parameter
     * @dev Can only be called through governance on home chain
     * @param newProposalThreshold New proposal threshold value
     */
    function setProposalThreshold(uint256 newProposalThreshold) public virtual override onlyGovernance onlyHomeChain {
        uint256 oldValue = proposalThreshold();
        _setProposalThreshold(newProposalThreshold);
        emit GovernanceParameterUpdated(OperationType.UPDATE_PROPOSAL_THRESHOLD, oldValue, newProposalThreshold);
    }

    /**
     * @notice Updates the quorum numerator
     * @dev Can only be called through governance on home chain
     * @param newQuorumNumerator New quorum numerator value (percentage * 100)
     */
    function updateQuorumNumerator(uint256 newQuorumNumerator)
        public
        virtual
        override(GovernorVotesQuorumFraction)
        onlyGovernance
        onlyHomeChain
    {
        uint256 oldValue = quorumNumerator();
        _updateQuorumNumerator(newQuorumNumerator);
        emit GovernanceParameterUpdated(OperationType.UPDATE_QUORUM, oldValue, newQuorumNumerator);
    }

    /**
     * @notice Generates proof for cross-chain parameter updates
     * @dev Can only be called on home chain
     * @param operationType Type of parameter being updated
     * @param value Encoded value for the parameter update
     * @return Encoded proof data for parameter update
     */
    function generateParameterProof(
        OperationType operationType,
        bytes memory value
    )
        external
        view
        returns (bytes memory)
    {
        if (block.chainid != HOME) revert ProofsOnlyOnHomeChain();
        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(operationType), value));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return abi.encode(operationType, value, digest);
    }

    /**
     * @notice Claims a governance parameter update on a foreign chain
     * @dev Verifies a proof generated on the home chain and updates the corresponding parameter
     * @param proof Encoded proof data containing parameter type, value, and signature
     * @custom:security This function should only update parameters if the proof is valid
     */
    function claimParameterUpdate(bytes memory proof) external {
        (OperationType operationType, bytes memory value, bytes32 digest) =
            abi.decode(proof, (OperationType, bytes, bytes32));

        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(operationType), value));
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        if (digest != expectedDigest) revert InvalidParameterProof();

        if (operationType == OperationType.UPDATE_VOTING_DELAY) {
            uint48 newValue = uint48(bytes6(value));
            uint256 oldValue = votingDelay();
            _setVotingDelay(newValue);
            emit GovernanceParameterUpdated(operationType, oldValue, newValue);
        } else if (operationType == OperationType.UPDATE_VOTING_PERIOD) {
            uint32 newValue = uint32(bytes4(value));
            uint256 oldValue = votingPeriod();
            _setVotingPeriod(newValue);
            emit GovernanceParameterUpdated(operationType, oldValue, newValue);
        } else if (operationType == OperationType.UPDATE_PROPOSAL_THRESHOLD) {
            uint256 newValue = abi.decode(value, (uint256));
            uint256 oldValue = proposalThreshold();
            _setProposalThreshold(newValue);
            emit GovernanceParameterUpdated(operationType, oldValue, newValue);
        } else if (operationType == OperationType.UPDATE_QUORUM) {
            uint256 newValue = abi.decode(value, (uint256));
            uint256 oldValue = quorumNumerator();
            _updateQuorumNumerator(newValue);
            emit GovernanceParameterUpdated(operationType, oldValue, newValue);
        }
    }

    /**
     * @notice Submits a new proposal
     * @dev Required override to resolve diamond inheritance between Governor and GovProposalTracking
     * @param targets Array of target addresses for proposal calls
     * @param values Array of values for proposal calls
     * @param calldatas Array of calldatas for proposal calls
     * @param description Description of the proposal
     * @return proposalId The ID of the created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, GovProposalTracking)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    // Required overrides

    /**
     * @notice Gets the current voting delay
     * @dev Overrides Governor and GovernorSettings to provide the correct value
     * @return Current voting delay in blocks
     */
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @notice Gets the current voting period
     * @dev Overrides Governor and GovernorSettings to provide the correct value
     * @return Current voting period in blocks
     */
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @notice Gets the quorum required for a specific block
     * @dev Overrides Governor and GovernorVotesQuorumFraction to provide the correct quorum calculation
     * @param blockNumber Block number to check quorum for
     * @return Minimum number of votes required for quorum
     */
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    /**
     * @notice Gets the current proposal threshold
     * @dev Overrides Governor and GovernorSettings to provide the correct value
     * @return Minimum number of votes required to create a proposal
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /**
     * @notice Override _msgSender to support UserOperation context
     * @dev When executing via UserOp, returns the actual user instead of this contract
     * @return The effective message sender (user in UserOp context, or msg.sender otherwise)
     */
    function _msgSender() internal view virtual override returns (address) {
        address userOpSender = _currentUserOpSender();
        if (userOpSender != address(0)) {
            return userOpSender;
        }
        return msg.sender;
    }

    /**
     * @notice Allows the contract to receive ETH for gas sponsorship
     */
    receive() external payable override { }
}
