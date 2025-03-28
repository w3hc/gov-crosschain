// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { ERC721Burnable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ERC721Votes } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";

/**
 * @title Cross-chain Membership NFT Contract
 * @author Web3 Hackers Collective
 * @notice A non-transferable NFT implementation for DAO membership with cross-chain capabilities
 * @dev Extends OpenZeppelin's NFT standards with cross-chain operation support
 * @custom:security-contact julien@strat.cc
 */
contract NFT is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable, EIP712, ERC721Votes {
    /// @notice The chain ID where the contract was originally deployed
    uint256 public immutable HOME;

    /// @notice Next token ID to be minted
    uint256 private _nextTokenId;

    /// @notice Tracks token existence on each chain
    mapping(uint256 tokenId => bool exists) public existsOnChain;

    mapping(address delegator => address delegate) public crosschainDelegates;

    /// @notice Operation types for cross-chain message verification
    /// @dev Used to differentiate between different types of cross-chain operations
    enum OperationType {
        MINT,
        BURN,
        SET_METADATA,
        SET_DELEGATION
    }

    // Custom errors
    error OnlyHomeChainAllowed();
    error InvalidProof();
    error TokenAlreadyExists();
    error NFTNonTransferable();
    error InvalidDelegationState();

    /**
     * @notice Emitted when a membership is claimed on a new chain
     * @param tokenId The ID of the claimed token
     * @param member The address receiving the membership
     * @param claimer The address executing the claim
     */
    event MembershipClaimed(uint256 indexed tokenId, address indexed member, address indexed claimer);

    /**
     * @notice Emitted when a membership is revoked
     * @param tokenId The ID of the revoked token
     * @param member The address losing membership
     */
    event MembershipRevoked(uint256 indexed tokenId, address indexed member);

    /**
     * @notice Emitted when a token's metadata is updated
     * @param tokenId The ID of the updated token
     * @param newUri The new metadata URI
     */
    event MetadataUpdated(uint256 indexed tokenId, string newUri);

    event DelegationUpdated(address indexed delegator, address indexed delegate);
    event CrosschainDelegationClaimed(address indexed delegator, address indexed delegate, address indexed claimer);

    /**
     * @notice Restricts operations to the home chain
     * @dev Used to ensure certain operations only occur on the chain where the contract was originally deployed
     */
    modifier onlyHomeChain() {
        if (block.chainid != HOME) revert OnlyHomeChainAllowed();
        _;
    }

    /**
     * @notice Initializes the NFT contract with initial members
     * @dev Sets up ERC721 parameters and mints initial tokens
     * @param _home The chain ID where this contract is considered home
     * @param initialOwner The initial contract owner (typically governance)
     * @param _firstMembers Array of initial member addresses
     * @param _uri Initial token URI
     * @param _name Token collection name
     * @param _symbol Token collection symbol
     */
    constructor(
        uint256 _home,
        address initialOwner,
        address[] memory _firstMembers,
        string memory _uri,
        string memory _name,
        string memory _symbol
    )
        ERC721(_name, _symbol)
        Ownable(initialOwner)
        EIP712(_name, "1")
    {
        HOME = _home;
        for (uint256 i; i < _firstMembers.length; i++) {
            _mint(_firstMembers[i], _uri);
            _delegate(_firstMembers[i], _firstMembers[i]);
        }
    }

    // Home Chain Operations

    /**
     * @notice Mints a new membership token
     * @dev Only callable by owner on home chain
     * @param to Recipient address
     * @param uri Token metadata URI
     */
    function safeMint(address to, string memory uri) public onlyOwner onlyHomeChain {
        _mint(to, uri);
        _delegate(to, to);
    }

    /**
     * @notice Revokes a membership
     * @dev Only callable by owner on home chain
     * @param tokenId ID of token to burn
     */
    function govBurn(uint256 tokenId) public onlyOwner onlyHomeChain {
        _govBurn(tokenId);
    }

    /**
     * @notice Updates a token's metadata
     * @dev Only callable by owner on home chain
     * @param tokenId ID of token to update
     * @param uri New metadata URI
     */
    function setMetadata(uint256 tokenId, string memory uri) public onlyOwner onlyHomeChain {
        _updateTokenMetadata(tokenId, uri);
    }

    // Cross-chain Operation Proofs

    /**
     * @notice Generates proof for cross-chain minting
     * @dev Creates a signed message proving token ownership and metadata
     * @param tokenId ID of token
     * @return Encoded proof data containing token details and signature
     */
    function generateMintProof(uint256 tokenId) external view returns (bytes memory) {
        if (block.chainid != HOME) revert OnlyHomeChainAllowed();
        address to = ownerOf(tokenId);
        string memory uri = tokenURI(tokenId);

        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.MINT), tokenId, to, uri));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(tokenId, to, uri, digest);
    }

    /**
     * @notice Generates proof for cross-chain burning
     * @dev Creates a signed message proving burn authorization
     * @param tokenId ID of token to burn
     * @return Encoded proof data containing burn details and signature
     */
    function generateBurnProof(uint256 tokenId) external view returns (bytes memory) {
        if (block.chainid != HOME) revert OnlyHomeChainAllowed();
        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.BURN), tokenId));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return abi.encode(tokenId, digest);
    }

    /**
     * @notice Generates proof for cross-chain metadata updates
     * @dev Creates a signed message proving metadata update authorization
     * @param tokenId Token ID to update
     * @param uri New metadata URI
     * @return Encoded proof data containing update details and signature
     */
    function generateMetadataProof(uint256 tokenId, string memory uri) external view returns (bytes memory) {
        if (block.chainid != HOME) revert OnlyHomeChainAllowed();
        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.SET_METADATA), tokenId, uri));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return abi.encode(tokenId, uri, digest);
    }

    function delegate(address delegatee) public virtual override onlyHomeChain {
        super.delegate(delegatee);
        crosschainDelegates[msg.sender] = delegatee;
        emit DelegationUpdated(msg.sender, delegatee);
    }

    function generateDelegationProof(address delegator, address delegatee) external view returns (bytes memory) {
        if (block.chainid != HOME) revert OnlyHomeChainAllowed();
        if (crosschainDelegates[delegator] != delegatee) revert InvalidDelegationState();

        bytes32 message =
            keccak256(abi.encodePacked(address(this), uint8(OperationType.SET_DELEGATION), delegator, delegatee));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        return abi.encode(delegator, delegatee, digest);
    }

    /**
     * @notice Claims a membership on a foreign chain
     * @dev Verifies proof and mints token on foreign chain
     * @param proof Proof generated on home chain
     */
    function claimMint(bytes memory proof) external {
        (uint256 tokenId, address to, string memory uri, bytes32 digest) =
            abi.decode(proof, (uint256, address, string, bytes32));

        if (existsOnChain[tokenId]) revert TokenAlreadyExists();

        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.MINT), tokenId, to, uri));
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        if (digest != expectedDigest) revert InvalidProof();
        _mint(to, uri);
        emit MembershipClaimed(tokenId, to, msg.sender);
    }

    /**
     * @notice Claims a burn operation on a foreign chain
     * @dev Verifies proof and burns token on foreign chain
     * @param proof Proof generated on home chain
     */
    function claimBurn(bytes memory proof) external {
        (uint256 tokenId, bytes32 digest) = abi.decode(proof, (uint256, bytes32));

        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.BURN), tokenId));
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        if (digest != expectedDigest) revert InvalidProof();

        address owner = ownerOf(tokenId);
        _update(address(0), tokenId, owner);
        existsOnChain[tokenId] = false;

        emit MembershipRevoked(tokenId, owner);
    }

    /**
     * @notice Claims a metadata update on a foreign chain
     * @dev Verifies proof and updates token metadata on foreign chain
     * @param proof Proof generated on home chain
     */
    function claimMetadataUpdate(bytes memory proof) external {
        (uint256 tokenId, string memory uri, bytes32 digest) = abi.decode(proof, (uint256, string, bytes32));

        bytes32 message = keccak256(abi.encodePacked(address(this), uint8(OperationType.SET_METADATA), tokenId, uri));
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        if (digest != expectedDigest) revert InvalidProof();

        _setTokenURI(tokenId, uri);
        existsOnChain[tokenId] = true;
        emit MetadataUpdated(tokenId, uri);
    }

    function claimDelegation(bytes memory proof) external {
        (address delegator, address delegatee, bytes32 digest) = abi.decode(proof, (address, address, bytes32));

        bytes32 message =
            keccak256(abi.encodePacked(address(this), uint8(OperationType.SET_DELEGATION), delegator, delegatee));
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        if (digest != expectedDigest) revert InvalidProof();

        _delegate(delegator, delegatee);
        crosschainDelegates[delegator] = delegatee;
        emit CrosschainDelegationClaimed(delegator, delegatee, msg.sender);
    }

    // Internal Functions

    /**
     * @dev Internal function to mint new token with metadata
     * @param to Address receiving the token
     * @param uri Metadata URI for the token
     */
    function _mint(address to, string memory uri) private {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        existsOnChain[tokenId] = true;
    }

    /**
     * @dev Internal function to burn token through governance
     * @param tokenId ID of token to burn
     */
    function _govBurn(uint256 tokenId) private {
        address owner = ownerOf(tokenId);
        _update(address(0), tokenId, owner);
        existsOnChain[tokenId] = false;
        emit MembershipRevoked(tokenId, owner);
    }

    /**
     * @dev Internal function to update token metadata
     * @param tokenId ID of token to update
     * @param uri New metadata URI
     */
    function _updateTokenMetadata(uint256 tokenId, string memory uri) private {
        _setTokenURI(tokenId, uri);
        emit MetadataUpdated(tokenId, uri);
    }

    // Required Overrides

    /**
     * @dev Override of ERC721's _update to make tokens non-transferable
     * @param to Target address (only allowed to be zero address for burns)
     * @param tokenId Token ID being updated
     * @param auth Address initiating the update
     * @return Previous owner of the token
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable, ERC721Votes)
        returns (address)
    {
        if (auth != address(0) && to != address(0)) revert NFTNonTransferable();
        return super._update(to, tokenId, auth);
    }

    /**
     * @notice Increases an account's token balance
     * @dev Internal function required by inherited contracts
     * @param account Address to increase balance for
     * @param value Amount to increase by
     */
    function _increaseBalance(
        address account,
        uint128 value
    )
        internal
        override(ERC721, ERC721Enumerable, ERC721Votes)
    {
        super._increaseBalance(account, value);
    }

    /**
     * @notice Gets the token URI
     * @dev Returns the metadata URI for a given token
     * @param tokenId ID of the token
     * @return URI string for the token metadata
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @notice Checks if the contract supports a given interface
     * @dev Implements interface detection for ERC721 and extensions
     * @param interfaceId Interface identifier to check
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Gets the current timestamp
     * @dev Used for voting snapshots, returns block timestamp as uint48
     * @return Current block timestamp
     */
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /**
     * @notice Gets the clock mode for voting snapshots
     * @dev Returns a description of how the clock value should be interpreted
     * @return String indicating timestamp-based clock mode
     */
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }
}
