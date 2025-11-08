# Standards & EIPs Reference

This document outlines all Ethereum standards and EIPs (Ethereum Improvement Proposals) implemented in the Gov
cross-chain governance system.

## Table of Contents

1. [Core Standards](#core-standards)
2. [Governance Standards](#governance-standards)
3. [Storage Standards](#storage-standards)
4. [Token Standards](#token-standards)
5. [Cryptography Standards](#cryptography-standards)
6. [Implementation Details](#implementation-details)

---

## Core Standards

### EIP-7702: Set EOA Account Code

**Status**: PRODUCTION READY **Implementation**: Native protocol support (no custom code required) **Networks**: 329+
EVM chains including Ethereum, Optimism, Base, Arbitrum, Polygon, BSC, and more

EIP-7702 is the **primary gasless transaction mechanism** for the Gov contract. It allows EOAs (Externally Owned
Accounts) to temporarily delegate their code execution to a contract through authorization signatures.

**How It Works:**

Users sign an authorization that allows their EOA to execute with the Gov contract's code. This enables:

- **Zero ETH required** - DAO treasury pays all gas
- **Direct function calls** - No relayer needed
- **Native protocol support** - Lower gas costs
- **Simple UX** - One authorization signature, then normal calls

**Who Pays for Gas:**

| Action                 | Who Signs      | Who Pays Gas  | Who Executes             |
| ---------------------- | -------------- | ------------- | ------------------------ |
| **Sign Authorization** | User (offline) | Nobody (free) | Nobody                   |
| **Submit Transaction** | User OR anyone | DAO treasury  | User's EOA with Gov code |

**Key Point**: With EIP-7702, the user signs an authorization offline (no gas). Then when they (or anyone) submit a
transaction with that authorization, the DAO treasury pays the gas, but the transaction executes in the context of the
user's EOA with the Gov contract's code.

**Implementation:**

```typescript
// 1. User signs authorization (offline, free)
const authorization = {
  chainId: 1,
  address: govContractAddress, // User's EOA delegates to Gov contract
  nonce: 0n,
};

const signature = await wallet.signAuthorization(authorization);

// 2. User (or anyone) submits transaction with authorization
// The DAO treasury pays gas, but msg.sender is the user's EOA
await walletClient.sendTransaction({
  to: govContractAddress,
  data: encodeFunctionData({
    abi: govAbi,
    functionName: "propose",
    args: [targets, values, calldatas, description],
  }),
  authorizationList: [authorization], // This makes it work!
});
```

**Benefits:**

- Members participate with ZERO ETH in their wallets
- DAO treasury sponsors all gas costs automatically
- No custom verification code needed (protocol-level)
- Lower gas costs than custom implementations
- Works with standard wallet interfaces

**Reference**: https://eips.ethereum.org/EIPS/eip-7702

---

### EIP-191: Signed Data Standard

**Status**: Fully Implemented **Implementation**: [src/Gov.sol](../src/Gov.sol), [src/NFT.sol](../src/NFT.sol)

Used for signing and verifying cross-chain proofs and operations.

**Implementation:**

```solidity
// Signing format
bytes32 digest = keccak256(
    abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
);
```

**Where used:**

- Cross-chain proof generation (Gov.sol:133, 221)
- Secure message signing for parameter updates
- Cross-chain synchronization verification

**Reference**: https://eips.ethereum.org/EIPS/eip-191

---

## Governance Standards

### Governor Standard (OpenZeppelin)

**Status**: Fully Implemented **Implementation**: [src/Gov.sol](../src/Gov.sol)

The Gov contract extends OpenZeppelin's Governor implementation with custom extensions.

**Components used:**

- `Governor` - Core governance functionality
- `GovernorSettings` - Configurable governance parameters
- `GovernorCountingSimple` - Simple vote counting (For/Against/Abstain)
- `GovernorVotes` - Vote weight tracking from ERC721Votes tokens
- `GovernorVotesQuorumFraction` - Percentage-based quorum

**Custom extensions:**

- `GovProposalTracking` - Track all proposal IDs for enumeration

**Key functions:**

- `propose()` - Create governance proposals
- `castVote()` - Vote on proposals
- `execute()` - Execute successful proposals

**Reference**: https://docs.openzeppelin.com/contracts/governance

---

## Token Standards

### ERC-721: Non-Fungible Token Standard

**Status**: Fully Implemented **Implementation**: [src/NFT.sol](../src/NFT.sol)

Membership tokens implementing ERC-721 with extensions.

**Extensions used:**

- `ERC721Enumerable` - Token enumeration capabilities
- `ERC721URIStorage` - Per-token metadata URIs
- `ERC721Burnable` - Token burning functionality
- `ERC721Votes` - Voting power delegation

**Key features:**

- One-member-one-vote (non-transferable after mint)
- Delegatable voting power
- Cross-chain membership proofs
- Soulbound token characteristics

**Reference**: https://eips.ethereum.org/EIPS/eip-721

---

### ERC-721 Votes Extension

**Status**: Fully Implemented **Implementation**: [src/NFT.sol](../src/NFT.sol)

Extends ERC-721 with vote delegation and voting power tracking.

**Key features:**

- `delegate()` - Delegate voting power to another address
- `getVotes()` - Get current voting power
- `getPastVotes()` - Get historical voting power at specific block
- Checkpoint system for vote weight history

**Integration:**

- Used by Governor contract for vote counting
- Enables historical vote weight queries
- Supports delegation without token transfer

**Reference**: https://docs.openzeppelin.com/contracts/votes

---

### ERC-5192: Minimal Soulbound NFTs

**Status**: Partially Implemented **Implementation**: [src/NFT.sol](../src/NFT.sol#L408-L418)

Membership NFTs are non-transferable (soulbound) after initial mint.

**Implementation:**

```solidity
function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721, ERC721Enumerable, ERC721Votes)
    returns (address)
{
    address from = _ownerOf(tokenId);
    // Prevent transfers (except minting and burning)
    if (from != address(0) && to != address(0)) {
        revert TokensAreNonTransferable();
    }
    return super._update(to, tokenId, auth);
}
```

**Characteristics:**

- Tokens cannot be transferred between addresses
- Tokens can be minted (address(0) → user)
- Tokens can be burned (user → address(0))
- Ensures 1-member-1-vote integrity

**Reference**: https://eips.ethereum.org/EIPS/eip-5192

---

## Cryptography Standards

### EIP-712: Typed Structured Data Hashing and Signing

**Status**: Fully Implemented **Implementation**: [src/NFT.sol](../src/NFT.sol)

Used for cross-chain delegation and structured data signing.

**Implementation:**

```solidity
contract NFT is EIP712 {
    constructor() EIP712("NFT Name", "1") {
        // ...
    }
}
```

**Use cases:**

- Cross-chain delegation signatures
- Structured data signing for proofs
- Domain separation for security

**Reference**: https://eips.ethereum.org/EIPS/eip-712

---

## Implementation Details

### Standards Compliance Matrix

| Standard              | Status  | Location | Notes                       |
| --------------------- | ------- | -------- | --------------------------- |
| EIP-7702              | Full    | Protocol | Native gasless transactions |
| EIP-191               | Full    | Gov.sol  | Message signing             |
| ERC-721               | Full    | NFT.sol  | Membership tokens           |
| ERC-721Votes          | Full    | NFT.sol  | Vote delegation             |
| ERC-5192              | Partial | NFT.sol  | Soulbound behavior          |
| EIP-712               | Full    | NFT.sol  | Typed data signing          |
| OpenZeppelin Governor | Full    | Gov.sol  | Governance core             |

---

### Why These Standards?

#### EIP-7702 (Account Abstraction)

**Problem**: Users need ETH to participate in governance, creating a barrier to entry. **Solution**: Users sign
authorizations offline, and the DAO treasury pays gas when transactions are submitted.

**Gas Payment Flow:**

1. User signs authorization (offline, free)
2. User submits transaction with authorization
3. Protocol recognizes authorization
4. Transaction executes in user's EOA context with Gov contract code
5. DAO treasury pays the gas automatically

#### ERC-721Votes (Voting NFTs)

**Problem**: Need verifiable membership and voting power tracking. **Solution**: NFT-based membership with built-in vote
delegation and historical tracking.

#### ERC-5192 (Soulbound)

**Problem**: Transferable membership tokens could enable vote buying. **Solution**: Non-transferable tokens ensure
genuine member participation.

#### EIP-712 (Typed Data)

**Problem**: Cross-chain operations need secure, structured signatures. **Solution**: Domain-separated typed data
signing for cross-chain proofs.

---

### EIP-7702 Deep Dive: Who Pays What?

Understanding the gas payment model with EIP-7702:

**Scenario 1: User Proposes**

```typescript
// Step 1: User signs authorization (FREE - offline)
const auth = await wallet.signAuthorization({
  chainId: 1,
  address: govContractAddress,
  nonce: 0n,
});

// Step 2: User submits transaction (DAO PAYS GAS)
await wallet.sendTransaction({
  to: govContractAddress,
  data: encodeProposal(...),
  authorizationList: [auth], // Magic happens here
});

// Result:
// - User's wallet: Still at 0 ETH ✓
// - DAO treasury: Reduced by gas cost
// - msg.sender in contract: User's address
// - Execution context: User's EOA with Gov code
```

**Scenario 2: Relayer Submits for User**

```typescript
// User signs authorization offline
const userAuth = await userWallet.signAuthorization({
  chainId: 1,
  address: govContractAddress,
  nonce: 0n,
});

// Relayer submits with user's authorization
await relayerWallet.sendTransaction({
  to: govContractAddress,
  data: encodeProposal(...),
  authorizationList: [userAuth], // User's authorization
});

// Result:
// - User's wallet: Still at 0 ETH ✓
// - Relayer's wallet: Unchanged (didn't pay gas)
// - DAO treasury: Reduced by gas cost
// - msg.sender in contract: Relayer's address
// - Execution context: User's EOA with Gov code
```

**Key Insight**: The authorization allows the user's EOA to "become" the Gov contract temporarily. The DAO treasury pays
gas because the Gov contract is configured to sponsor transactions.

---

### Cross-Chain Standards

The Gov system implements custom cross-chain synchronization using proven cryptographic techniques:

**Proof Generation:**

```solidity
bytes32 message = keccak256(abi.encodePacked(
    address(this),
    uint8(operationType),
    value
));
bytes32 digest = keccak256(abi.encodePacked(
    "\x19Ethereum Signed Message:\n32",
    message
));
```

**Proof Verification:**

- Deterministic message hashing
- EIP-191 signature format
- Chain-specific contract addresses
- Operation type encoding

This approach ensures:

- Verifiable parameter updates across chains
- Replay attack prevention
- Source chain authentication

---

### Testing Standards

All implementations are tested following Foundry best practices:

- **Unit tests**: Individual function testing
- **Integration tests**: Multi-contract workflows
- **EIP-7702 tests**: Gasless transaction validation
- **Gas snapshots**: Gas optimization tracking

See [test/unit/GovEIP7702.t.sol](../test/unit/GovEIP7702.t.sol) for comprehensive EIP-7702 test examples.

---

## Summary

The Gov cross-chain governance system leverages carefully selected Ethereum standards to provide:

1. ✅ **Gasless Participation** via EIP-7702 (Native protocol support)
2. ✅ **Secure Membership** via ERC-721 and ERC-5192 soulbound tokens
3. ✅ **Robust Governance** via OpenZeppelin Governor standards
4. ✅ **Cross-chain Sync** via EIP-191 and EIP-712 cryptographic proofs

### Interaction Method

The system uses **EIP-7702** for governance participation:

**EIP-7702 (Native Account Abstraction)**

- ✅ Live on 329+ EVM mainnets
- ✅ Native protocol support
- ✅ Zero ETH required for users
- ✅ DAO treasury pays all gas
- ✅ Most gas efficient
- ✅ Simplest UX
- See: [INTEGRATION_GUIDE.md § EIP-7702](INTEGRATION_GUIDE.md#eip-7702-method-native-account-abstraction)

Each standard serves a specific purpose in creating a secure, accessible, and decentralized governance system that works
across multiple blockchain networks.

---

## References

- [EIP-7702: Set EOA Account Code](https://eips.ethereum.org/EIPS/eip-7702)
- [EIP-191: Signed Data Standard](https://eips.ethereum.org/EIPS/eip-191)
- [ERC-721: Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [ERC-5192: Minimal Soulbound NFTs](https://eips.ethereum.org/EIPS/eip-5192)
- [EIP-712: Typed Structured Data](https://eips.ethereum.org/EIPS/eip-712)
- [OpenZeppelin Governor Documentation](https://docs.openzeppelin.com/contracts/governance)
- [OpenZeppelin Votes Documentation](https://docs.openzeppelin.com/contracts/votes)
- [Viem EIP-7702 Support](https://viem.sh/experimental/eip7702)
- [EIP-7702 Playground](https://github.com/w3hc/eip7702-playground)
