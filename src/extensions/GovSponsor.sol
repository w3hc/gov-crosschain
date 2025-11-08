// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title GovSponsor
 * @author W3HC
 * @notice Transaction sponsorship extension for Gov contract with EIP-4337 paymaster support
 * @dev Allows the DAO treasury to sponsor gas costs for all members (NFT holders)
 * @dev Supports both gas refund pattern and true gasless transactions via UserOperations
 * @custom:security-contact julien@strat.cc
 */
abstract contract GovSponsor {
    /**
     * @notice Thrown when ETH transfer to recipient fails
     * @dev May occur if recipient contract has a failing fallback function
     */
    error TransferFailed();

    /**
     * @notice Thrown when the sender is not a DAO member
     * @dev Only NFT holders can use sponsored transactions
     */
    error NotAMember();

    /**
     * @notice Thrown when user operation signature is invalid
     */
    error InvalidUserOpSignature();

    /**
     * @notice Thrown when user operation nonce is invalid
     */
    error InvalidNonce();

    /**
     * @notice UserOperation struct for EIP-4337 style gasless transactions
     */
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes signature;
    }

    /**
     * @dev ERC-7201 storage namespace for GovSponsor
     * @custom:storage-location erc7201:govsponsor.storage
     */
    struct GovSponsorStorage {
        // Tracks gas spent by each member when using sponsored transactions
        mapping(address => uint256) gasSpent;
        // Nonce for each member's UserOperations
        mapping(address => uint256) nonces;
        // The membership NFT contract
        IERC721 membershipToken;
        // Address of the user on whose behalf a UserOp is being executed (0 if not in UserOp)
        address currentUserOpSender;
    }

    // keccak256(abi.encode(uint256(keccak256("govsponsor.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GOV_SPONSOR_STORAGE_LOCATION =
        0x1c4e6d5e8b3a2f7d9c1e4b8f2a6d5c3e9f1b7a4d8c2e6f3a9b5d1c8e4f7a2b00;

    /**
     * @dev Get the sponsor storage
     */
    function _getGovSponsorStorage() private pure returns (GovSponsorStorage storage s) {
        bytes32 position = GOV_SPONSOR_STORAGE_LOCATION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Emitted when a UserOperation is executed
     * @param sender The member who initiated the operation
     * @param nonce The nonce used
     * @param success Whether the operation succeeded
     * @param gasUsed The amount of gas consumed
     */
    event UserOperationExecuted(address indexed sender, uint256 nonce, bool success, uint256 gasUsed);

    /**
     * @notice Initializes the sponsorship extension
     * @param _membershipToken The NFT contract representing membership
     */
    function _initializeGovSponsor(IERC721 _membershipToken) internal {
        GovSponsorStorage storage s = _getGovSponsorStorage();
        s.membershipToken = _membershipToken;
    }

    /**
     * @notice Get gas spent by a specific member
     * @param member The address to check gas usage for
     * @return Amount of gas used by the member
     */
    function gasSpent(address member) external view returns (uint256) {
        return _getGovSponsorStorage().gasSpent[member];
    }

    /**
     * @notice Helper function to verify if an address is a member
     * @param member Address to check
     * @return True if the address holds a membership NFT
     */
    function isMember(address member) public view returns (bool) {
        return _getGovSponsorStorage().membershipToken.balanceOf(member) > 0;
    }

    /**
     * @notice Get the current nonce for a member's UserOperations
     * @param member Address to check
     * @return Current nonce
     */
    function getNonce(address member) external view returns (uint256) {
        return _getGovSponsorStorage().nonces[member];
    }

    /**
     * @notice Get the current UserOp sender (for internal use by Gov)
     * @dev Returns address(0) if not currently executing a UserOp
     * @return The address of the user whose UserOp is being executed
     */
    function _currentUserOpSender() internal view returns (address) {
        return _getGovSponsorStorage().currentUserOpSender;
    }

    /**
     * @notice Execute a UserOperation on behalf of a member with zero ETH
     * @dev This is the paymaster function - allows anyone to submit operations for members
     * @dev The DAO treasury pays all gas costs
     * @param userOp The UserOperation to execute
     * @return success Whether the operation succeeded
     */
    function executeUserOp(UserOperation calldata userOp) external returns (bool success) {
        GovSponsorStorage storage s = _getGovSponsorStorage();

        // Verify sender is a member
        if (s.membershipToken.balanceOf(userOp.sender) == 0) revert NotAMember();

        // Verify and increment nonce
        if (userOp.nonce != s.nonces[userOp.sender]) revert InvalidNonce();
        s.nonces[userOp.sender]++;

        // Validate signature
        bytes32 userOpHash = getUserOpHash(userOp);
        address recovered = recoverSigner(userOpHash, userOp.signature);
        if (recovered != userOp.sender) revert InvalidUserOpSignature();

        // Set the current UserOp sender for context
        s.currentUserOpSender = userOp.sender;

        // Record gas before execution
        uint256 gasStart = gasleft();

        // Execute the call
        (success,) = address(this).call{ gas: userOp.callGasLimit }(userOp.callData);

        // Calculate total gas used
        uint256 gasUsed = gasStart - gasleft() + userOp.preVerificationGas;

        // Track gas spent
        s.gasSpent[userOp.sender] += gasUsed;

        // Clear the UserOp sender
        s.currentUserOpSender = address(0);

        emit UserOperationExecuted(userOp.sender, userOp.nonce, success, gasUsed);

        return success;
    }

    /**
     * @notice Compute the hash of a UserOperation
     * @param userOp The UserOperation
     * @return The hash
     */
    function getUserOpHash(UserOperation calldata userOp) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Recover the signer from a signature
     * @param hash The hash that was signed (already includes EIP-191 prefix if using vm.sign)
     * @param signature The signature
     * @return The signer address
     */
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) return address(0);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) v += 27;

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }

        // vm.sign already adds the "\x19Ethereum Signed Message:\n32" prefix
        // so we just ecrecover directly from the hash
        return ecrecover(hash, v, r, s);
    }
}
