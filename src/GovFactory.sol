// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Gov } from "./Gov.sol";
import { NFT } from "./NFT.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title GovFactory
 * @author Web3 Hackers Collective
 * @notice Factory contract to deploy DAO governance system across multiple chains
 * @dev Uses CREATE2 for deterministic addresses across chains
 * @custom:security-contact julien@strat.cc
 */
contract GovFactory {
    /// @notice Structure to store deployment data
    struct DeploymentInfo {
        address nft;
        address gov;
        uint256 chainId;
        uint256 timestamp;
        bool isHomeChain;
    }

    /// @notice Structure to group deployment parameters
    struct DeployParams {
        address[] initialMembers;
        string manifestoCid;
        string name;
        string nftSymbol;
        string nftURI;
        uint48 votingDelay;
        uint32 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumPercentage;
    }

    /// @notice Home chain ID where the original governance system is deployed
    uint256 public immutable HOME_CHAIN_ID;

    /// @notice Registry of deployments across different chains
    mapping(uint256 chainId => DeploymentInfo deploymentInfo) public deployments;

    /// @notice Array of chain IDs where the system has been deployed
    uint256[] public deployedChains;

    /// @notice Address of the factory owner
    address public owner;

    /// @notice Standard salt for deterministic deployments
    bytes32 public immutable DEPLOYMENT_SALT;

    /// @notice Events for tracking deployments
    event DAODeployed(address indexed nft, address indexed gov, uint256 indexed chainId, string name, bool isHomeChain);

    /// @notice Event for tracking ownership changes
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Custom errors
    error OnlyOwner();
    error DeploymentAlreadyExists();
    error DeploymentFailed();
    error InvalidDeployment();

    /**
     * @notice Restricts function to owner only
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Factory constructor
     * @param _homeChainId The ID of the home chain where the original system is deployed
     * @param _salt Custom salt for deterministic deployments (use the same across all chains)
     */
    constructor(uint256 _homeChainId, bytes32 _salt) {
        HOME_CHAIN_ID = _homeChainId;
        DEPLOYMENT_SALT = _salt;
        owner = msg.sender;
    }

    /**
     * @notice Deploys NFT and Gov contracts on the current chain with deterministic addresses
     * @param initialMembers Array of initial member addresses to receive NFTs
     * @param manifestoCid IPFS CID of the DAO's manifesto
     * @param name Name of the governance system/DAO
     * @param nftSymbol Symbol for the NFT token
     * @param nftURI Base URI for the NFT metadata
     * @param votingDelay Time before voting begins (in blocks)
     * @param votingPeriod Duration of voting period (in blocks)
     * @param proposalThreshold Minimum votes needed to create a proposal
     * @param quorumPercentage Minimum participation percentage required
     * @return nftAddress The address of the deployed NFT contract
     * @return govAddress The address of the deployed Gov contract
     */
    function deployDAO(
        address[] memory initialMembers,
        string memory manifestoCid,
        string memory name,
        string memory nftSymbol,
        string memory nftURI,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    )
        public
        onlyOwner
        returns (address nftAddress, address govAddress)
    {
        // Check if deployment already exists for this chain
        if (deployments[block.chainid].nft != address(0)) revert DeploymentAlreadyExists();

        // Package parameters into a struct to reduce stack variables
        DeployParams memory params = DeployParams({
            initialMembers: initialMembers,
            manifestoCid: manifestoCid,
            name: name,
            nftSymbol: nftSymbol,
            nftURI: nftURI,
            votingDelay: votingDelay,
            votingPeriod: votingPeriod,
            proposalThreshold: proposalThreshold,
            quorumPercentage: quorumPercentage
        });

        // Deploy contracts
        (nftAddress, govAddress) = _deployContracts(params);

        // Store deployment information
        bool isHome = block.chainid == HOME_CHAIN_ID;
        deployments[block.chainid] = DeploymentInfo({
            nft: nftAddress,
            gov: govAddress,
            chainId: block.chainid,
            timestamp: block.timestamp,
            isHomeChain: isHome
        });

        // Add to list of deployed chains
        deployedChains.push(block.chainid);

        // Emit deployment event
        emit DAODeployed(nftAddress, govAddress, block.chainid, name, isHome);

        return (nftAddress, govAddress);
    }

    /**
     * @notice Internal function that handles the actual contract deployments
     * @param params Struct containing all deployment parameters
     * @return nftAddress The address of the deployed NFT contract
     * @return govAddress The address of the deployed Gov contract
     */
    function _deployContracts(DeployParams memory params) internal returns (address nftAddress, address govAddress) {
        // Deploy NFT contract
        nftAddress = _deployNFT(params.initialMembers, params.name, params.nftSymbol, params.nftURI);

        if (nftAddress == address(0)) revert DeploymentFailed();
        NFT nft = NFT(nftAddress);

        // Deploy Gov contract
        govAddress = _deployGov(
            nft,
            params.manifestoCid,
            params.name,
            params.votingDelay,
            params.votingPeriod,
            params.proposalThreshold,
            params.quorumPercentage
        );

        if (govAddress == address(0)) revert DeploymentFailed();

        // Transfer NFT ownership to governance contract
        nft.transferOwnership(govAddress);

        return (nftAddress, govAddress);
    }

    /**
     * @notice Internal function to deploy the NFT contract
     */
    function _deployNFT(
        address[] memory initialMembers,
        string memory name,
        string memory nftSymbol,
        string memory nftURI
    )
        internal
        returns (address)
    {
        // Create deterministic salt for NFT
        bytes32 nftSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "NFT"));

        // Create bytecode for NFT contract
        bytes memory nftCreationCode = abi.encodePacked(
            type(NFT).creationCode,
            abi.encode(
                HOME_CHAIN_ID,
                address(this), // Initial owner is this factory
                initialMembers,
                nftURI,
                name,
                nftSymbol
            )
        );

        // Deploy NFT contract with CREATE2
        return Create2.deploy(0, nftSalt, nftCreationCode);
    }

    /**
     * @notice Internal function to deploy the Gov contract
     */
    function _deployGov(
        NFT nft,
        string memory manifestoCid,
        string memory name,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    )
        internal
        returns (address)
    {
        // Create deterministic salt for Gov
        bytes32 govSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "GOV"));

        // Create bytecode for Gov contract
        bytes memory govCreationCode = abi.encodePacked(
            type(Gov).creationCode,
            abi.encode(
                HOME_CHAIN_ID, nft, manifestoCid, name, votingDelay, votingPeriod, proposalThreshold, quorumPercentage
            )
        );

        // Deploy Gov contract with CREATE2
        return Create2.deploy(0, govSalt, govCreationCode);
    }

    /**
     * @notice Gets the number of chains where the DAO has been deployed
     * @return The count of deployed chains
     */
    function getDeploymentCount() external view returns (uint256) {
        return deployedChains.length;
    }

    /**
     * @notice Gets all chain deployments
     * @return An array of deployment information structures
     */
    function getAllDeployments() external view returns (DeploymentInfo[] memory) {
        DeploymentInfo[] memory allDeployments = new DeploymentInfo[](deployedChains.length);

        for (uint256 i = 0; i < deployedChains.length; i++) {
            allDeployments[i] = deployments[deployedChains[i]];
        }

        return allDeployments;
    }

    /**
     * @notice Checks if a specific chain ID has a deployment
     * @param chainId The chain ID to check
     * @return True if the chain has a deployment, false otherwise
     */
    function hasDeployment(uint256 chainId) external view returns (bool) {
        return deployments[chainId].nft != address(0);
    }

    /**
     * @notice Computes expected NFT contract address before deployment
     * @param initialMembers Array of initial member addresses to receive NFTs
     * @param name Name of the governance system/DAO
     * @param nftSymbol Symbol for the NFT token
     * @param nftURI Base URI for the NFT metadata
     * @return Expected NFT contract address
     */
    function computeNFTAddress(
        address[] memory initialMembers,
        string memory name,
        string memory nftSymbol,
        string memory nftURI
    )
        public
        view
        returns (address)
    {
        bytes32 nftSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "NFT"));

        bytes memory nftCreationCode = abi.encodePacked(
            type(NFT).creationCode, abi.encode(HOME_CHAIN_ID, address(this), initialMembers, nftURI, name, nftSymbol)
        );

        return Create2.computeAddress(nftSalt, keccak256(nftCreationCode));
    }

    /**
     * @notice Computes expected Gov contract address before deployment
     * @param nftAddress The address of the NFT contract
     * @param manifestoCid IPFS CID of the DAO's manifesto
     * @param name Name of the governance system/DAO
     * @param votingDelay Time before voting begins (in blocks)
     * @param votingPeriod Duration of voting period (in blocks)
     * @param proposalThreshold Minimum votes needed to create a proposal
     * @param quorumPercentage Minimum participation percentage required
     * @return Expected Gov contract address
     */
    function computeGovAddress(
        address nftAddress,
        string memory manifestoCid,
        string memory name,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    )
        public
        view
        returns (address)
    {
        bytes32 govSalt = keccak256(abi.encodePacked(DEPLOYMENT_SALT, "GOV"));

        bytes memory govCreationCode = abi.encodePacked(
            type(Gov).creationCode,
            abi.encode(
                HOME_CHAIN_ID,
                NFT(payable(nftAddress)),
                manifestoCid,
                name,
                votingDelay,
                votingPeriod,
                proposalThreshold,
                quorumPercentage
            )
        );

        return Create2.computeAddress(govSalt, keccak256(govCreationCode));
    }

    /**
     * @notice Pre-computes both NFT and Gov addresses for a given configuration
     * @param initialMembers Array of initial member addresses to receive NFTs
     * @param manifestoCid IPFS CID of the DAO's manifesto
     * @param name Name of the governance system/DAO
     * @param nftSymbol Symbol for the NFT token
     * @param nftURI Base URI for the NFT metadata
     * @param votingDelay Time before voting begins (in blocks)
     * @param votingPeriod Duration of voting period (in blocks)
     * @param proposalThreshold Minimum votes needed to create a proposal
     * @param quorumPercentage Minimum participation percentage required
     * @return nftAddress Expected NFT contract address
     * @return govAddress Expected Gov contract address
     */
    function computeDeploymentAddresses(
        address[] memory initialMembers,
        string memory manifestoCid,
        string memory name,
        string memory nftSymbol,
        string memory nftURI,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    )
        external
        view
        returns (address nftAddress, address govAddress)
    {
        nftAddress = computeNFTAddress(initialMembers, name, nftSymbol, nftURI);
        govAddress = computeGovAddress(
            nftAddress, manifestoCid, name, votingDelay, votingPeriod, proposalThreshold, quorumPercentage
        );

        return (nftAddress, govAddress);
    }

    /**
     * @notice Transfers ownership of the factory
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
