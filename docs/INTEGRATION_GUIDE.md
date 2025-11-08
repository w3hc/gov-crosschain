# Gov Integration Guide (EIP-7702)

This guide explains how to integrate gasless governance using EIP-7702 with the Gov contract.

## Table of Contents

1. [Overview](#overview)
2. [EIP-7702 Gasless Method](#eip-7702-gasless-method)
3. [Traditional Method (Fallback)](#traditional-method-fallback)
4. [Next.js Integration](#nextjs-integration)
5. [Security Considerations](#security-considerations)

---

## Overview

The Gov contract uses **EIP-7702** for gasless transactions. Members can participate in governance with **ZERO ETH** in
their wallets - the DAO treasury automatically pays all gas costs.

### How It Works

1. User signs an **authorization** offline (free, no gas)
2. User (or anyone) submits a transaction with that authorization
3. The DAO treasury pays the gas
4. The transaction executes in the user's EOA context with the Gov contract's code

### Who Pays for Gas?

| Action                 | Who Signs      | Who Pays Gas     | Who Executes             |
| ---------------------- | -------------- | ---------------- | ------------------------ |
| **Sign Authorization** | User (offline) | Nobody (free)    | Nobody                   |
| **Submit Transaction** | User OR anyone | **DAO treasury** | User's EOA with Gov code |

**Key Point**: The user never needs ETH. The authorization allows their EOA to temporarily "become" the Gov contract,
and the DAO treasury pays for all gas costs.

---

## EIP-7702 Gasless Method

### Requirements

- User must be a DAO member (hold an NFT)
- User needs **ZERO ETH** (DAO treasury pays gas)
- Wallet must support EIP-7702 (Viem, ethers.js v6+, etc.)

### propose() - Create a Proposal

**Function Signature:**

```solidity
function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
) public returns (uint256 proposalId)
```

**Implementation (Viem):**

```typescript
import { walletClient, publicClient } from "./config";
import { encodeFunctionData } from "viem";
import { govAbi } from "./abis";

// Step 1: Sign authorization (offline, free)
const authorization = await walletClient.signAuthorization({
  contractAddress: govContractAddress,
  chainId: 11155111, // Sepolia
});

// Step 2: Prepare proposal data
const targets = [targetContractAddress];
const values = [0n]; // No ETH sent
const calldatas = [
  encodeFunctionData({
    abi: targetAbi,
    functionName: "setValue",
    args: [42],
  }),
];
const description = "Proposal #1: Set value to 42";

// Step 3: Submit with authorization (DAO pays gas)
const hash = await walletClient.sendTransaction({
  to: govContractAddress,
  data: encodeFunctionData({
    abi: govAbi,
    functionName: "propose",
    args: [targets, values, calldatas, description],
  }),
  authorizationList: [authorization], // This makes it gasless!
});

const receipt = await publicClient.waitForTransactionReceipt({ hash });
console.log("Proposal created! User paid 0 ETH.");
```

**Result:**

- User's wallet: Still at 0 ETH ✓
- DAO treasury: Paid the gas
- Proposal created successfully

---

### castVote() - Vote on a Proposal

**Function Signature:**

```solidity
function castVote(
    uint256 proposalId,
    uint8 support  // 0 = Against, 1 = For, 2 = Abstain
) public returns (uint256 balance)
```

**Implementation (Viem):**

```typescript
// Step 1: Sign authorization
const authorization = await walletClient.signAuthorization({
  contractAddress: govContractAddress,
  chainId: 11155111,
});

// Step 2: Cast vote (DAO pays gas)
const hash = await walletClient.sendTransaction({
  to: govContractAddress,
  data: encodeFunctionData({
    abi: govAbi,
    functionName: "castVote",
    args: [proposalId, 1], // 1 = Vote FOR
  }),
  authorizationList: [authorization],
});

await publicClient.waitForTransactionReceipt({ hash });
console.log("Vote cast! User paid 0 ETH.");
```

---

### execute() - Execute a Successful Proposal

**Function Signature:**

```solidity
function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) public payable returns (uint256 proposalId)
```

**Implementation (Viem):**

```typescript
import { keccak256, toBytes } from "viem";

// Step 1: Sign authorization
const authorization = await walletClient.signAuthorization({
  contractAddress: govContractAddress,
  chainId: 11155111,
});

// Step 2: Prepare execution parameters (same as proposal)
const targets = [targetContractAddress];
const values = [0n];
const calldatas = [
  encodeFunctionData({
    abi: targetAbi,
    functionName: "setValue",
    args: [42],
  }),
];
const descriptionHash = keccak256(toBytes("Proposal #1: Set value to 42"));

// Step 3: Execute (DAO pays gas)
const hash = await walletClient.sendTransaction({
  to: govContractAddress,
  data: encodeFunctionData({
    abi: govAbi,
    functionName: "execute",
    args: [targets, values, calldatas, descriptionHash],
  }),
  authorizationList: [authorization],
});

await publicClient.waitForTransactionReceipt({ hash });
console.log("Proposal executed! User paid 0 ETH.");
```

---

## Traditional Method (Fallback)

If the user prefers to pay their own gas or their wallet doesn't support EIP-7702:

### propose() - Traditional

```typescript
// User needs ETH for gas
const hash = await walletClient.writeContract({
  address: govContractAddress,
  abi: govAbi,
  functionName: "propose",
  args: [targets, values, calldatas, description],
});

await publicClient.waitForTransactionReceipt({ hash });
console.log("Proposal created! User paid gas.");
```

### castVote() - Traditional

```typescript
const hash = await walletClient.writeContract({
  address: govContractAddress,
  abi: govAbi,
  functionName: "castVote",
  args: [proposalId, 1], // 1 = Vote FOR
});

await publicClient.waitForTransactionReceipt({ hash });
```

---

## Next.js Integration

### Complete Governance Page Example

```typescript
"use client";

import { useState } from "react";
import { useAccount, useWalletClient, usePublicClient } from "wagmi";
import { encodeFunctionData, keccak256, toBytes } from "viem";
import { govAbi, targetAbi } from "./abis";

const GOV_ADDRESS = "0x..."; // Your Gov contract address
const TARGET_ADDRESS = "0x..."; // Target contract for proposals

export default function GovernancePage() {
  const { address } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();

  const [proposalId, setProposalId] = useState("");
  const [loading, setLoading] = useState(false);

  // Create Proposal (EIP-7702 - Gasless)
  const handlePropose = async () => {
    if (!walletClient) return;

    try {
      setLoading(true);

      // Sign authorization
      const authorization = await walletClient.signAuthorization({
        contractAddress: GOV_ADDRESS,
      });

      // Prepare proposal
      const targets = [TARGET_ADDRESS];
      const values = [0n];
      const calldatas = [
        encodeFunctionData({
          abi: targetAbi,
          functionName: "setValue",
          args: [42],
        }),
      ];
      const description = "Set value to 42";

      // Submit (DAO pays gas)
      const hash = await walletClient.sendTransaction({
        to: GOV_ADDRESS,
        data: encodeFunctionData({
          abi: govAbi,
          functionName: "propose",
          args: [targets, values, calldatas, description],
        }),
        authorizationList: [authorization],
      });

      await publicClient.waitForTransactionReceipt({ hash });
      alert("Proposal created! You paid 0 ETH.");
    } catch (error) {
      console.error(error);
      alert("Failed to create proposal");
    } finally {
      setLoading(false);
    }
  };

  // Cast Vote (EIP-7702 - Gasless)
  const handleVote = async (support: number) => {
    if (!walletClient || !proposalId) return;

    try {
      setLoading(true);

      // Sign authorization
      const authorization = await walletClient.signAuthorization({
        contractAddress: GOV_ADDRESS,
      });

      // Submit vote (DAO pays gas)
      const hash = await walletClient.sendTransaction({
        to: GOV_ADDRESS,
        data: encodeFunctionData({
          abi: govAbi,
          functionName: "castVote",
          args: [BigInt(proposalId), support],
        }),
        authorizationList: [authorization],
      });

      await publicClient.waitForTransactionReceipt({ hash });
      alert(`Vote cast! You paid 0 ETH.`);
    } catch (error) {
      console.error(error);
      alert("Failed to vote");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">Governance</h1>

      <div className="space-y-6">
        {/* Create Proposal */}
        <div className="border rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">Create Proposal</h2>
          <button
            onClick={handlePropose}
            disabled={loading || !address}
            className="bg-blue-500 text-white px-6 py-2 rounded-lg disabled:opacity-50"
          >
            {loading ? "Processing..." : "Propose (0 ETH)"}
          </button>
          <p className="text-sm text-gray-600 mt-2">
            ✓ Gasless via EIP-7702 - DAO treasury pays gas
          </p>
        </div>

        {/* Vote on Proposal */}
        <div className="border rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4">Vote on Proposal</h2>
          <input
            type="text"
            placeholder="Proposal ID"
            value={proposalId}
            onChange={(e) => setProposalId(e.target.value)}
            className="border rounded px-4 py-2 mb-4 w-full"
          />
          <div className="flex gap-4">
            <button
              onClick={() => handleVote(1)}
              disabled={loading || !address || !proposalId}
              className="bg-green-500 text-white px-6 py-2 rounded-lg disabled:opacity-50"
            >
              Vote FOR (0 ETH)
            </button>
            <button
              onClick={() => handleVote(0)}
              disabled={loading || !address || !proposalId}
              className="bg-red-500 text-white px-6 py-2 rounded-lg disabled:opacity-50"
            >
              Vote AGAINST (0 ETH)
            </button>
          </div>
          <p className="text-sm text-gray-600 mt-2">
            ✓ Gasless via EIP-7702 - DAO treasury pays gas
          </p>
        </div>
      </div>
    </div>
  );
}
```

### Wagmi Configuration

```typescript
// config.ts
import { http, createConfig } from "wagmi";
import { sepolia, mainnet } from "wagmi/chains";
import { injected } from "wagmi/connectors";

export const config = createConfig({
  chains: [sepolia, mainnet],
  connectors: [injected()],
  transports: {
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
});
```

---

## Security Considerations

### Authorization Signatures

**DO:**

- ✅ Sign authorizations only for contracts you trust
- ✅ Verify the contract address before signing
- ✅ Use EIP-7702 for temporary code delegation only

**DON'T:**

- ❌ Sign authorizations for unknown contracts
- ❌ Reuse authorizations across different chains without verification
- ❌ Share authorization signatures publicly

### Gas Payment Model

**Understanding who pays:**

1. **User signs authorization (offline)** → Nobody pays (free)
2. **User submits transaction** → DAO treasury pays gas
3. **Relayer submits for user** → DAO treasury pays gas (not the relayer)

**Important**: The DAO treasury ALWAYS pays gas when EIP-7702 authorizations are used with the Gov contract.

### Membership Verification

The Gov contract automatically verifies that the caller is a DAO member (holds an NFT). This check happens at the
protocol level, so unauthorized users cannot participate even with valid authorizations.

---

## Best Practices

### 1. Progressive Enhancement

Offer both EIP-7702 (gasless) and traditional methods:

```typescript
async function propose() {
  try {
    // Try EIP-7702 first (gasless)
    await proposeWithEIP7702();
  } catch (error) {
    // Fallback to traditional (user pays gas)
    await proposeTraditional();
  }
}
```

### 2. Clear UX Communication

Always inform users about gas payment:

```typescript
<button>
  Propose (0 ETH) ✓ DAO pays gas
</button>
```

### 3. Error Handling

```typescript
try {
  const authorization = await walletClient.signAuthorization({
    contractAddress: GOV_ADDRESS,
  });
} catch (error) {
  if (error.message.includes("User rejected")) {
    alert("Authorization cancelled");
  } else if (error.message.includes("not supported")) {
    alert("Your wallet doesn't support EIP-7702. Use traditional method.");
  } else {
    alert("Failed to sign authorization");
  }
}
```

### 4. Transaction Monitoring

```typescript
const hash = await walletClient.sendTransaction({
  to: GOV_ADDRESS,
  data: ...,
  authorizationList: [authorization],
});

// Monitor transaction
const receipt = await publicClient.waitForTransactionReceipt({
  hash,
  confirmations: 2, // Wait for 2 confirmations
});

if (receipt.status === "success") {
  console.log("Transaction successful");
} else {
  console.log("Transaction failed");
}
```

---

## Summary

The Gov contract uses **EIP-7702** to enable:

- ✅ **Zero ETH required** - Members don't need gas money
- ✅ **DAO treasury pays** - All gas costs covered by the DAO
- ✅ **Simple integration** - Standard wallet interfaces
- ✅ **Native protocol** - Lower gas costs than custom implementations
- ✅ **Secure** - Built-in membership verification

For more technical details, see:

- [STANDARDS.md](./STANDARDS.md) - EIP specifications and implementation details
- [Test Examples](../test/unit/GovEIP7702.t.sol) - Comprehensive test suite
- [EIP-7702 Playground](https://github.com/w3hc/eip7702-playground) - Interactive examples

---

## References

- [EIP-7702 Specification](https://eips.ethereum.org/EIPS/eip-7702)
- [Viem EIP-7702 Support](https://viem.sh/experimental/eip7702)
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/governance)
- [Wagmi Documentation](https://wagmi.sh)
