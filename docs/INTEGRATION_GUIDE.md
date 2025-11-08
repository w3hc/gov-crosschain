# GovSponsor Integration Guide

This guide explains how to interact with the Gov contract using both traditional transactions (requiring ETH for gas)
and gasless UserOperations (requiring zero ETH).

## Table of Contents

1. [Overview](#overview)
2. [Traditional Method (With Gas)](#traditional-method-with-gas)
3. [Gasless Method (UserOperations)](#gasless-method-useroperations)
4. [EIP-7702 Method (Native Account Abstraction)](#eip-7702-method-native-account-abstraction)
5. [Comparison Table](#comparison-table)
6. [Integration Examples](#integration-examples)
7. [Next.js Integration](#nextjs-integration)
8. [Security Considerations](#security-considerations)
9. [Best Practices](#best-practices)

---

## Overview

The Gov contract extends OpenZeppelin's Governor with the GovSponsor extension, which provides **three ways** to
interact with governance functions:

- **Traditional**: Users pay their own gas (standard Ethereum transactions)
- **Gasless (UserOperations)**: DAO treasury sponsors gas via custom UserOp system (members need ZERO ETH)
- **EIP-7702 (Recommended)**: Native account abstraction - simplest and most efficient gasless method (ZERO ETH
  required)

All governance functions (`propose`, `castVote`, `execute`) support all three methods.

---

## Traditional Method (With Gas)

### Requirements

- User must be a DAO member (hold an NFT)
- User must have ETH to pay for gas
- User submits transactions directly to the blockchain

### propose()

**Function Signature:**

```solidity
function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
) public returns (uint256 proposalId)
```

**Usage:**

```javascript
// Example: Propose to set a value on a target contract
const targets = [targetContract.address];
const values = [0]; // No ETH sent
const calldatas = [targetContract.interface.encodeFunctionData("setValue", [42])];
const description = "Proposal #1: Set value to 42";

// User must have ETH for gas
const tx = await govContract.propose(targets, values, calldatas, description, { gasLimit: 500000 });
const receipt = await tx.wait();
```

**Requirements:**

- Caller must hold at least `proposalThreshold()` votes
- Caller pays gas fees

---

### castVote()

**Function Signature:**

```solidity
function castVote(
    uint256 proposalId,
    uint8 support
) public returns (uint256 balance)
```

**Parameters:**

- `proposalId`: The ID of the proposal
- `support`: Vote choice (0 = Against, 1 = For, 2 = Abstain)

**Usage:**

```javascript
// User votes FOR a proposal
const tx = await govContract.castVote(
  proposalId,
  1, // 1 = For
  { gasLimit: 200000 },
);
await tx.wait();
```

**Requirements:**

- Proposal must be in Active state
- Caller must be a member (hold NFT)
- Caller pays gas fees

---

### execute()

**Function Signature:**

```solidity
function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) public payable returns (uint256 proposalId)
```

**Usage:**

```javascript
// Execute a successful proposal
const targets = [targetContract.address];
const values = [0];
const calldatas = [targetContract.interface.encodeFunctionData("setValue", [42])];
const descriptionHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Proposal #1: Set value to 42"));

const tx = await govContract.execute(targets, values, calldatas, descriptionHash, { gasLimit: 300000 });
await tx.wait();
```

**Requirements:**

- Proposal must have succeeded (reached quorum and majority voted For)
- Voting period must have ended
- Caller pays gas fees

---

## Gasless Method (UserOperations)

### Requirements

- User must be a DAO member (hold an NFT)
- User needs **ZERO ETH** - completely gasless
- DAO treasury must have ETH to sponsor transactions
- User signs operations offline
- Anyone can submit the signed UserOperation

### How It Works

1. **User creates a UserOperation** with the desired function call
2. **User signs the UserOperation** offline (no gas needed)
3. **Anyone submits** the signed UserOperation to `executeUserOp()`
4. **DAO treasury pays** all gas costs

### executeUserOp()

**Function Signature:**

```solidity
function executeUserOp(UserOperation calldata userOp)
    external
    returns (bool success)

struct UserOperation {
    address sender;              // The member executing the operation
    uint256 nonce;              // Anti-replay nonce
    bytes callData;             // The encoded function call
    uint256 callGasLimit;       // Gas limit for the call
    uint256 verificationGasLimit; // Gas for signature verification
    uint256 preVerificationGas; // Gas for pre-execution checks
    uint256 maxFeePerGas;       // Max gas price
    uint256 maxPriorityFeePerGas; // Max priority fee
    bytes signature;            // User's signature
}
```

---

### Gasless propose()

**Step 1: Create UserOperation**

```javascript
// Encode the propose call
const proposeCalldata = govContract.interface.encodeFunctionData("propose", [targets, values, calldatas, description]);

// Get user's current nonce
const nonce = await govContract.getNonce(userAddress);

// Create UserOperation
const userOp = {
  sender: userAddress,
  nonce: nonce,
  callData: proposeCalldata,
  callGasLimit: 500000,
  verificationGasLimit: 100000,
  preVerificationGas: 21000,
  maxFeePerGas: ethers.utils.parseUnits("50", "gwei"),
  maxPriorityFeePerGas: ethers.utils.parseUnits("2", "gwei"),
  signature: "0x", // Placeholder
};
```

**Step 2: Sign UserOperation**

```javascript
// Get the hash to sign
const userOpHash = await govContract.getUserOpHash(userOp);

// User signs with their private key (OFFLINE - NO GAS NEEDED)
const signature = await userWallet.signMessage(ethers.utils.arrayify(userOpHash));

userOp.signature = signature;
```

**Step 3: Submit UserOperation**

```javascript
// ANYONE can submit this (even a relayer service)
// The submitter pays gas temporarily, but gets refunded by DAO treasury
const tx = await govContract.executeUserOp(userOp);
const receipt = await tx.wait();

// Check if successful
console.log("UserOp success:", receipt.events.find((e) => e.event === "UserOperationExecuted").args.success);
```

**User's ETH Balance:** **0 ETH** (completely gasless!)

---

### Gasless castVote()

**Step 1: Create UserOperation**

```javascript
const voteCalldata = govContract.interface.encodeFunctionData(
  "castVote",
  [proposalId, 1], // 1 = For
);

const nonce = await govContract.getNonce(voterAddress);

const userOp = {
  sender: voterAddress,
  nonce: nonce,
  callData: voteCalldata,
  callGasLimit: 200000,
  verificationGasLimit: 100000,
  preVerificationGas: 21000,
  maxFeePerGas: ethers.utils.parseUnits("50", "gwei"),
  maxPriorityFeePerGas: ethers.utils.parseUnits("2", "gwei"),
  signature: "0x",
};
```

**Step 2: Sign UserOperation**

```javascript
const userOpHash = await govContract.getUserOpHash(userOp);
const signature = await voterWallet.signMessage(ethers.utils.arrayify(userOpHash));
userOp.signature = signature;
```

**Step 3: Submit UserOperation**

```javascript
// Anyone submits (relayer, another member, etc.)
const tx = await govContract.executeUserOp(userOp);
await tx.wait();
```

---

### Gasless execute()

**Step 1: Create UserOperation**

```javascript
const executeCalldata = govContract.interface.encodeFunctionData("execute", [
  targets,
  values,
  calldatas,
  descriptionHash,
]);

const nonce = await govContract.getNonce(executorAddress);

const userOp = {
  sender: executorAddress,
  nonce: nonce,
  callData: executeCalldata,
  callGasLimit: 300000,
  verificationGasLimit: 100000,
  preVerificationGas: 21000,
  maxFeePerGas: ethers.utils.parseUnits("50", "gwei"),
  maxPriorityFeePerGas: ethers.utils.parseUnits("2", "gwei"),
  signature: "0x",
};
```

**Step 2: Sign UserOperation**

```javascript
const userOpHash = await govContract.getUserOpHash(userOp);
const signature = await executorWallet.signMessage(ethers.utils.arrayify(userOpHash));
userOp.signature = signature;
```

**Step 3: Submit UserOperation**

```javascript
const tx = await govContract.executeUserOp(userOp);
await tx.wait();
```

---

## EIP-7702 Method (Native Account Abstraction)

### Requirements

- User must be a DAO member (hold an NFT)
- User needs **ZERO ETH** - completely gasless
- DAO treasury sponsors transactions
- Network must support EIP-7702 (329+ EVM chains including Ethereum, Base, Arbitrum, Optimism, etc.)
- User signs authorization once, then calls functions directly

### How It Works

EIP-7702 allows EOAs to temporarily delegate their execution to a smart contract. This is **simpler** than
UserOperations:

1. **User signs authorization** to delegate to Gov contract (one-time per session)
2. **User calls functions directly** - no relayer needed
3. **DAO treasury pays gas** automatically
4. **Protocol handles everything** - no custom code required

---

### EIP-7702 propose()

**Step 1: Sign Authorization (Once per Session)**

```javascript
import { signAuthorization } from "viem/experimental";

// User authorizes their EOA to delegate to Gov contract
const authorization = await walletClient.signAuthorization({
  contractAddress: govContractAddress,
});

// Authorization structure:
// {
//   chainId: 1,
//   address: govContractAddress,
//   nonce: 0n,
//   r: '0x...',
//   s: '0x...',
//   yParity: 1
// }
```

**Step 2: Call propose() Directly**

```javascript
// User can now call propose directly - no UserOp needed!
const hash = await walletClient.sendTransaction({
  to: govContractAddress,
  data: encodeFunctionData({
    abi: govAbi,
    functionName: "propose",
    args: [targets, values, calldatas, description],
  }),
  authorizationList: [authorization], // Include authorization
  // DAO pays gas - user needs ZERO ETH!
});

await publicClient.waitForTransactionReceipt({ hash });
```

**User's ETH Balance:** **0 ETH** (completely gasless!)

---

### EIP-7702 castVote()

**Assuming authorization already signed:**

```javascript
const hash = await walletClient.sendTransaction({
  to: govContractAddress,
  data: encodeFunctionData({
    abi: govAbi,
    functionName: "castVote",
    args: [proposalId, 1], // 1 = For
  }),
  authorizationList: [authorization],
});

await publicClient.waitForTransactionReceipt({ hash });
```

**Benefits over UserOp:**

- No UserOp struct creation
- No custom signature verification
- No relayer submission step
- Direct function calls
- Lower gas costs (protocol-optimized)

---

### EIP-7702 execute()

```javascript
const descriptionHash = keccak256(toUtf8Bytes(description));

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
```

---

## Comparison Table

| Feature                 | Traditional    | UserOperation         | EIP-7702             |
| ----------------------- | -------------- | --------------------- | -------------------- |
| **User needs ETH**      | Yes            | No (ZERO ETH)         | No (ZERO ETH)        |
| **Who pays gas**        | User           | DAO Treasury          | DAO Treasury         |
| **Requires signature**  | Yes (tx)       | Yes (offline UserOp)  | Yes (authorization)  |
| **Who submits**         | User only      | Anyone (relayer)      | User directly        |
| **Membership required** | Yes            | Yes                   | Yes                  |
| **Implementation**      | Built-in       | Custom contract       | Protocol-native      |
| **Complexity**          | Simple         | Moderate              | Simple               |
| **Gas efficiency**      | Standard       | Higher (verification) | Optimized (protocol) |
| **Network support**     | All EVM        | All EVM               | 329+ EVM chains      |
| **Code required**       | None           | GovSponsor.sol        | None                 |
| **Relayer needed**      | No             | Yes                   | No                   |
| **Use case**            | Users with ETH | Legacy support        | **Recommended**      |
| **Gas tracking**        | N/A            | Tracked per member    | N/A                  |
| **Nonce system**        | Ethereum nonce | Contract nonce        | Ethereum nonce       |

---

## Integration Examples

### Example 1: Complete Governance Workflow (Traditional)

```javascript
// 1. PROPOSE (Alice pays gas)
const targets = [targetContract.address];
const values = [0];
const calldatas = [targetContract.interface.encodeFunctionData("setValue", [42])];
const description = "Set value to 42";

const proposeTx = await govContract.connect(alice).propose(targets, values, calldatas, description);
const proposeReceipt = await proposeTx.wait();
const proposalId = proposeReceipt.events[0].args.proposalId;

// 2. WAIT for voting to start
await ethers.provider.send("evm_mine", []);

// 3. CAST VOTES (Alice and Bob pay gas)
await govContract.connect(alice).castVote(proposalId, 1);
await govContract.connect(bob).castVote(proposalId, 1);

// 4. WAIT for voting period to end
for (let i = 0; i < 100; i++) {
  await ethers.provider.send("evm_mine", []);
}

// 5. EXECUTE (Anyone pays gas)
const descriptionHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(description));
await govContract.connect(alice).execute(targets, values, calldatas, descriptionHash);
```

**Cost:** Alice + Bob pay gas fees

---

### Example 2: Complete Governance Workflow (Gasless)

```javascript
// Helper function to create and sign UserOp
async function createUserOp(signer, callData) {
  const nonce = await govContract.getNonce(signer.address);
  const userOp = {
    sender: signer.address,
    nonce: nonce,
    callData: callData,
    callGasLimit: 500000,
    verificationGasLimit: 100000,
    preVerificationGas: 21000,
    maxFeePerGas: ethers.utils.parseUnits("50", "gwei"),
    maxPriorityFeePerGas: ethers.utils.parseUnits("2", "gwei"),
    signature: "0x",
  };

  const userOpHash = await govContract.getUserOpHash(userOp);
  const signature = await signer.signMessage(ethers.utils.arrayify(userOpHash));
  userOp.signature = signature;

  return userOp;
}

// 1. PROPOSE (Alice signs, relayer submits)
const proposeCalldata = govContract.interface.encodeFunctionData("propose", [targets, values, calldatas, description]);
const proposeOp = await createUserOp(alice, proposeCalldata);

// Relayer submits (pays gas temporarily, gets refunded)
const proposeTx = await govContract.connect(relayer).executeUserOp(proposeOp);
await proposeTx.wait();

// Get proposal ID from event
const proposalId = await govContract.proposalIds(0);

// 2. WAIT for voting to start
await ethers.provider.send("evm_mine", []);

// 3. CAST VOTES (Alice and Bob sign, relayer submits)
const voteCalldata = govContract.interface.encodeFunctionData("castVote", [proposalId, 1]);

const aliceVoteOp = await createUserOp(alice, voteCalldata);
await govContract.connect(relayer).executeUserOp(aliceVoteOp);

const bobVoteOp = await createUserOp(bob, voteCalldata);
await govContract.connect(relayer).executeUserOp(bobVoteOp);

// 4. WAIT for voting period to end
for (let i = 0; i < 100; i++) {
  await ethers.provider.send("evm_mine", []);
}

// 5. EXECUTE (Alice signs, relayer submits)
const descriptionHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(description));
const executeCalldata = govContract.interface.encodeFunctionData("execute", [
  targets,
  values,
  calldatas,
  descriptionHash,
]);

const executeOp = await createUserOp(alice, executeCalldata);
await govContract.connect(relayer).executeUserOp(executeOp);
```

**Cost:** Alice + Bob have ZERO ETH. DAO treasury pays all gas costs.

---

### Example 3: Hybrid Approach

You can mix both methods in the same workflow:

```javascript
// Alice (has ETH) proposes traditionally
const proposeTx = await govContract.connect(alice).propose(targets, values, calldatas, description);
const proposalId = (await proposeTx.wait()).events[0].args.proposalId;

// Bob (no ETH) votes via UserOp
const voteCalldata = govContract.interface.encodeFunctionData("castVote", [proposalId, 1]);
const bobVoteOp = await createUserOp(bob, voteCalldata);
await govContract.connect(relayer).executeUserOp(bobVoteOp);

// Alice votes traditionally
await govContract.connect(alice).castVote(proposalId, 1);

// Anyone executes traditionally
await govContract.connect(charlie).execute(targets, values, calldatas, descriptionHash);
```

---

## Next.js Integration

This section demonstrates how to integrate both traditional and gasless governance interactions in a Next.js
application.

### Project Setup

```bash
# Create Next.js app
npx create-next-app@latest my-dao-app

# Install dependencies
npm install ethers wagmi viem@2.x @tanstack/react-query
npm install @rainbow-me/rainbowkit  # Optional: for wallet connection UI
```

### Configuration

**lib/contracts.ts**

```typescript
export const GOV_CONTRACT_ADDRESS = "0x..."; // Your deployed Gov contract

export const GOV_ABI = [
  // Core governance functions
  "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
  "function execute(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) payable returns (uint256)",

  // UserOperation functions
  "function executeUserOp(tuple(address sender, uint256 nonce, bytes callData, uint256 callGasLimit, uint256 verificationGasLimit, uint256 preVerificationGas, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, bytes signature) userOp) returns (bool)",
  "function getNonce(address member) view returns (uint256)",
  "function getUserOpHash(tuple(address sender, uint256 nonce, bytes callData, uint256 callGasLimit, uint256 verificationGasLimit, uint256 preVerificationGas, uint256 maxFeePerGas, uint256 maxPriorityFeePerGas, bytes signature) userOp) view returns (bytes32)",
  "function isMember(address member) view returns (bool)",
  "function gasSpent(address member) view returns (uint256)",

  // View functions
  "function proposalIds(uint256 index) view returns (uint256)",
  "function state(uint256 proposalId) view returns (uint8)",

  // Events
  "event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)",
  "event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason)",
  "event UserOperationExecuted(address indexed sender, uint256 nonce, bool success, uint256 gasUsed)",
];
```

### Traditional Method in Next.js

**components/TraditionalPropose.tsx**

```typescript
"use client";

import { useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

export function TraditionalPropose() {
  const { address } = useAccount();
  const [description, setDescription] = useState("");
  const [targetAddress, setTargetAddress] = useState("");
  const [targetValue, setTargetValue] = useState("");

  const { data: hash, writeContract, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const handlePropose = async () => {
    if (!targetAddress || !description) return;

    // Example: Propose to send ETH to an address
    const targets = [targetAddress];
    const values = [parseEther(targetValue || "0")];
    const calldatas = ["0x"]; // Empty calldata for simple transfer

    writeContract({
      address: GOV_CONTRACT_ADDRESS,
      abi: GOV_ABI,
      functionName: "propose",
      args: [targets, values, calldatas, description],
    });
  };

  return (
    <div className="p-6 border rounded-lg">
      <h2 className="text-2xl font-bold mb-4">Create Proposal (Traditional)</h2>
      <p className="text-sm text-gray-600 mb-4">
        ⚠️ You will pay gas fees for this transaction
      </p>

      <div className="space-y-4">
        <input
          type="text"
          placeholder="Target Address"
          value={targetAddress}
          onChange={(e) => setTargetAddress(e.target.value)}
          className="w-full p-2 border rounded"
        />

        <input
          type="text"
          placeholder="ETH Amount"
          value={targetValue}
          onChange={(e) => setTargetValue(e.target.value)}
          className="w-full p-2 border rounded"
        />

        <textarea
          placeholder="Proposal Description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className="w-full p-2 border rounded"
          rows={4}
        />

        <button
          onClick={handlePropose}
          disabled={isPending || isConfirming}
          className="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600 disabled:bg-gray-400"
        >
          {isPending || isConfirming ? "Proposing..." : "Create Proposal"}
        </button>

        {isSuccess && (
          <div className="p-3 bg-green-100 text-green-800 rounded">
            Proposal created successfully!
          </div>
        )}
      </div>
    </div>
  );
}
```

**components/TraditionalVote.tsx**

```typescript
"use client";

import { useState } from "react";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

export function TraditionalVote() {
  const [proposalId, setProposalId] = useState("");
  const { data: hash, writeContract, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const handleVote = (support: 0 | 1 | 2) => {
    if (!proposalId) return;

    writeContract({
      address: GOV_CONTRACT_ADDRESS,
      abi: GOV_ABI,
      functionName: "castVote",
      args: [BigInt(proposalId), support],
    });
  };

  return (
    <div className="p-6 border rounded-lg">
      <h2 className="text-2xl font-bold mb-4">Vote (Traditional)</h2>
      <p className="text-sm text-gray-600 mb-4">
        ⚠️ You will pay gas fees for this transaction
      </p>

      <input
        type="text"
        placeholder="Proposal ID"
        value={proposalId}
        onChange={(e) => setProposalId(e.target.value)}
        className="w-full p-2 border rounded mb-4"
      />

      <div className="flex gap-2">
        <button
          onClick={() => handleVote(0)}
          disabled={isPending || isConfirming}
          className="flex-1 bg-red-500 text-white p-2 rounded hover:bg-red-600"
        >
          Against
        </button>

        <button
          onClick={() => handleVote(1)}
          disabled={isPending || isConfirming}
          className="flex-1 bg-green-500 text-white p-2 rounded hover:bg-green-600"
        >
          For
        </button>

        <button
          onClick={() => handleVote(2)}
          disabled={isPending || isConfirming}
          className="flex-1 bg-gray-500 text-white p-2 rounded hover:bg-gray-600"
        >
          Abstain
        </button>
      </div>

      {isSuccess && (
        <div className="mt-4 p-3 bg-green-100 text-green-800 rounded">
          Vote cast successfully!
        </div>
      )}
    </div>
  );
}
```

### Gasless Method in Next.js

**lib/userOp.ts**

```typescript
import { ethers } from "ethers";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "./contracts";

export interface UserOperation {
  sender: string;
  nonce: bigint;
  callData: string;
  callGasLimit: bigint;
  verificationGasLimit: bigint;
  preVerificationGas: bigint;
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  signature: string;
}

export async function createUserOp(
  provider: ethers.Provider,
  signer: ethers.Signer,
  callData: string,
): Promise<UserOperation> {
  const contract = new ethers.Contract(GOV_CONTRACT_ADDRESS, GOV_ABI, provider);
  const signerAddress = await signer.getAddress();

  // Get current nonce
  const nonce = await contract.getNonce(signerAddress);

  // Get current gas price
  const feeData = await provider.getFeeData();

  const userOp: UserOperation = {
    sender: signerAddress,
    nonce: nonce,
    callData: callData,
    callGasLimit: 500000n,
    verificationGasLimit: 100000n,
    preVerificationGas: 21000n,
    maxFeePerGas: feeData.maxFeePerGas || ethers.parseUnits("50", "gwei"),
    maxPriorityFeePerGas: feeData.maxPriorityFeePerGas || ethers.parseUnits("2", "gwei"),
    signature: "0x",
  };

  // Get hash to sign
  const userOpHash = await contract.getUserOpHash(userOp);

  // Sign the hash
  const signature = await signer.signMessage(ethers.getBytes(userOpHash));
  userOp.signature = signature;

  return userOp;
}
```

**components/GaslessPropose.tsx**

```typescript
"use client";

import { useState } from "react";
import { useAccount, useWalletClient, usePublicClient, useWriteContract } from "wagmi";
import { parseEther } from "viem";
import { ethers } from "ethers";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";
import { createUserOp } from "@/lib/userOp";

export function GaslessPropose() {
  const { address } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [description, setDescription] = useState("");
  const [targetAddress, setTargetAddress] = useState("");
  const [targetValue, setTargetValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState("");

  const { writeContract } = useWriteContract();

  const handleGaslessPropose = async () => {
    if (!walletClient || !publicClient || !address) return;

    setIsLoading(true);
    setStatus("Creating UserOperation...");

    try {
      // Convert wagmi clients to ethers
      const provider = new ethers.BrowserProvider(walletClient);
      const signer = await provider.getSigner();

      // Encode the propose call
      const iface = new ethers.Interface(GOV_ABI);
      const targets = [targetAddress];
      const values = [parseEther(targetValue || "0")];
      const calldatas = ["0x"];

      const proposeCalldata = iface.encodeFunctionData("propose", [
        targets,
        values,
        calldatas,
        description
      ]);

      // Create and sign UserOperation
      setStatus("Signing UserOperation... (No gas needed!)");
      const userOp = await createUserOp(provider, signer, proposeCalldata);

      // Submit UserOperation (via relayer or any account)
      setStatus("Submitting UserOperation...");
      writeContract({
        address: GOV_CONTRACT_ADDRESS,
        abi: GOV_ABI,
        functionName: "executeUserOp",
        args: [userOp],
      });

      setStatus("Proposal created successfully! You paid ZERO gas.");
    } catch (error) {
      console.error(error);
      setStatus("Error creating proposal");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="p-6 border rounded-lg bg-green-50">
      <h2 className="text-2xl font-bold mb-4">Create Proposal (Gasless)</h2>
      <p className="text-sm text-green-700 mb-4">
        ✅ You need ZERO ETH - DAO pays all gas costs!
      </p>

      <div className="space-y-4">
        <input
          type="text"
          placeholder="Target Address"
          value={targetAddress}
          onChange={(e) => setTargetAddress(e.target.value)}
          className="w-full p-2 border rounded"
        />

        <input
          type="text"
          placeholder="ETH Amount"
          value={targetValue}
          onChange={(e) => setTargetValue(e.target.value)}
          className="w-full p-2 border rounded"
        />

        <textarea
          placeholder="Proposal Description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className="w-full p-2 border rounded"
          rows={4}
        />

        <button
          onClick={handleGaslessPropose}
          disabled={isLoading}
          className="w-full bg-green-500 text-white p-2 rounded hover:bg-green-600 disabled:bg-gray-400"
        >
          {isLoading ? "Processing..." : "Create Proposal (Gasless)"}
        </button>

        {status && (
          <div className="p-3 bg-white border border-green-300 text-green-800 rounded">
            {status}
          </div>
        )}
      </div>
    </div>
  );
}
```

**components/GaslessVote.tsx**

```typescript
"use client";

import { useState } from "react";
import { useAccount, useWalletClient, usePublicClient, useWriteContract } from "wagmi";
import { ethers } from "ethers";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";
import { createUserOp } from "@/lib/userOp";

export function GaslessVote() {
  const { address } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [proposalId, setProposalId] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState("");

  const { writeContract } = useWriteContract();

  const handleGaslessVote = async (support: 0 | 1 | 2) => {
    if (!walletClient || !publicClient || !address || !proposalId) return;

    setIsLoading(true);
    setStatus("Creating UserOperation...");

    try {
      const provider = new ethers.BrowserProvider(walletClient);
      const signer = await provider.getSigner();

      // Encode the vote call
      const iface = new ethers.Interface(GOV_ABI);
      const voteCalldata = iface.encodeFunctionData("castVote", [
        BigInt(proposalId),
        support
      ]);

      // Create and sign UserOperation
      setStatus("Signing vote... (No gas needed!)");
      const userOp = await createUserOp(provider, signer, voteCalldata);

      // Submit UserOperation
      setStatus("Submitting vote...");
      writeContract({
        address: GOV_CONTRACT_ADDRESS,
        abi: GOV_ABI,
        functionName: "executeUserOp",
        args: [userOp],
      });

      setStatus("Vote cast successfully! You paid ZERO gas.");
    } catch (error) {
      console.error(error);
      setStatus("Error casting vote");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="p-6 border rounded-lg bg-green-50">
      <h2 className="text-2xl font-bold mb-4">Vote (Gasless)</h2>
      <p className="text-sm text-green-700 mb-4">
        ✅ You need ZERO ETH - DAO pays all gas costs!
      </p>

      <input
        type="text"
        placeholder="Proposal ID"
        value={proposalId}
        onChange={(e) => setProposalId(e.target.value)}
        className="w-full p-2 border rounded mb-4"
      />

      <div className="flex gap-2 mb-4">
        <button
          onClick={() => handleGaslessVote(0)}
          disabled={isLoading}
          className="flex-1 bg-red-500 text-white p-2 rounded hover:bg-red-600"
        >
          Against
        </button>

        <button
          onClick={() => handleGaslessVote(1)}
          disabled={isLoading}
          className="flex-1 bg-green-500 text-white p-2 rounded hover:bg-green-600"
        >
          For
        </button>

        <button
          onClick={() => handleGaslessVote(2)}
          disabled={isLoading}
          className="flex-1 bg-gray-500 text-white p-2 rounded hover:bg-gray-600"
        >
          Abstain
        </button>
      </div>

      {status && (
        <div className="p-3 bg-white border border-green-300 text-green-800 rounded">
          {status}
        </div>
      )}
    </div>
  );
}
```

### Complete Page Example

**app/governance/page.tsx**

```typescript
import { TraditionalPropose } from "@/components/TraditionalPropose";
import { TraditionalVote } from "@/components/TraditionalVote";
import { GaslessPropose } from "@/components/GaslessPropose";
import { GaslessVote } from "@/components/GaslessVote";

export default function GovernancePage() {
  return (
    <div className="container mx-auto p-8">
      <h1 className="text-4xl font-bold mb-8">DAO Governance</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
        <TraditionalPropose />
        <GaslessPropose />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <TraditionalVote />
        <GaslessVote />
      </div>
    </div>
  );
}
```

### API Route for Relayer (Optional)

**app/api/relay-userop/route.ts**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { ethers } from "ethers";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

export async function POST(request: NextRequest) {
  try {
    const userOp = await request.json();

    // Set up relayer wallet (keep private key in env vars)
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const relayer = new ethers.Wallet(process.env.RELAYER_PRIVATE_KEY!, provider);

    // Submit UserOperation
    const contract = new ethers.Contract(GOV_CONTRACT_ADDRESS, GOV_ABI, relayer);
    const tx = await contract.executeUserOp(userOp);
    const receipt = await tx.wait();

    return NextResponse.json({
      success: true,
      txHash: receipt.hash,
      gasUsed: receipt.gasUsed.toString(),
    });
  } catch (error: any) {
    return NextResponse.json(
      {
        success: false,
        error: error.message,
      },
      { status: 500 },
    );
  }
}
```

**Usage with Relayer API:**

```typescript
// In your component, instead of calling writeContract directly:
const response = await fetch("/api/relay-userop", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(userOp),
});

const result = await response.json();
if (result.success) {
  setStatus(`Transaction hash: ${result.txHash}`);
}
```

### Server Component Example - Display Proposals

**app/governance/proposals/page.tsx**

```typescript
import { ethers } from "ethers";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

async function getProposals() {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const contract = new ethers.Contract(GOV_CONTRACT_ADDRESS, GOV_ABI, provider);

  // Get all proposal events
  const filter = contract.filters.ProposalCreated();
  const events = await contract.queryFilter(filter);

  return events.map(event => ({
    proposalId: event.args?.proposalId.toString(),
    proposer: event.args?.proposer,
    description: event.args?.description,
    targets: event.args?.targets,
  }));
}

export default async function ProposalsPage() {
  const proposals = await getProposals();

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-4xl font-bold mb-8">Proposals</h1>

      <div className="space-y-4">
        {proposals.map((proposal) => (
          <div key={proposal.proposalId} className="p-6 border rounded-lg">
            <h3 className="text-xl font-bold">Proposal #{proposal.proposalId}</h3>
            <p className="text-gray-600 mt-2">{proposal.description}</p>
            <p className="text-sm text-gray-500 mt-2">
              Proposed by: {proposal.proposer}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### EIP-7702 Method in Next.js (Recommended)

**lib/eip7702.ts**

```typescript
import { signAuthorization } from "viem/experimental";
import { type WalletClient } from "viem";
import { GOV_CONTRACT_ADDRESS } from "./contracts";

export async function createAuthorization(walletClient: WalletClient) {
  const authorization = await walletClient.signAuthorization({
    contractAddress: GOV_CONTRACT_ADDRESS as `0x${string}`,
  });

  return authorization;
}
```

**components/EIP7702Propose.tsx**

```typescript
"use client";

import { useState } from "react";
import { useAccount, useWalletClient, usePublicClient, useWriteContract } from "wagmi";
import { parseEther, encodeFunctionData } from "viem";
import { signAuthorization } from "viem/experimental";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

export function EIP7702Propose() {
  const { address } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [description, setDescription] = useState("");
  const [targetAddress, setTargetAddress] = useState("");
  const [targetValue, setTargetValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState("");
  const [authorization, setAuthorization] = useState<any>(null);

  const handleAuthorize = async () => {
    if (!walletClient) return;

    setIsLoading(true);
    setStatus("Signing authorization...");

    try {
      const auth = await signAuthorization(walletClient, {
        contractAddress: GOV_CONTRACT_ADDRESS as `0x${string}`,
      });

      setAuthorization(auth);
      setStatus("Authorization signed! You can now propose gaslessly.");
    } catch (error) {
      console.error(error);
      setStatus("Error signing authorization");
    } finally {
      setIsLoading(false);
    }
  };

  const handlePropose = async () => {
    if (!walletClient || !authorization || !targetAddress || !description) return;

    setIsLoading(true);
    setStatus("Creating proposal...");

    try {
      const targets = [targetAddress as `0x${string}`];
      const values = [parseEther(targetValue || "0")];
      const calldatas = ["0x" as `0x${string}`];

      const data = encodeFunctionData({
        abi: GOV_ABI,
        functionName: "propose",
        args: [targets, values, calldatas, description],
      });

      const hash = await walletClient.sendTransaction({
        to: GOV_CONTRACT_ADDRESS as `0x${string}`,
        data,
        authorizationList: [authorization],
      });

      await publicClient?.waitForTransactionReceipt({ hash });
      setStatus("Proposal created successfully! You paid ZERO gas.");
    } catch (error) {
      console.error(error);
      setStatus("Error creating proposal");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="p-6 border rounded-lg bg-blue-50">
      <h2 className="text-2xl font-bold mb-4">Create Proposal (EIP-7702)</h2>
      <p className="text-sm text-blue-700 mb-4">
        ⚡ Native account abstraction - Simplest gasless method!
      </p>

      <div className="space-y-4">
        {!authorization && (
          <button
            onClick={handleAuthorize}
            disabled={isLoading}
            className="w-full bg-blue-600 text-white p-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
          >
            {isLoading ? "Authorizing..." : "1. Sign Authorization"}
          </button>
        )}

        {authorization && (
          <>
            <div className="p-3 bg-green-100 text-green-800 rounded text-sm">
              Authorization signed! You can now propose without gas.
            </div>

            <input
              type="text"
              placeholder="Target Address"
              value={targetAddress}
              onChange={(e) => setTargetAddress(e.target.value)}
              className="w-full p-2 border rounded"
            />

            <input
              type="text"
              placeholder="ETH Amount"
              value={targetValue}
              onChange={(e) => setTargetValue(e.target.value)}
              className="w-full p-2 border rounded"
            />

            <textarea
              placeholder="Proposal Description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full p-2 border rounded"
              rows={4}
            />

            <button
              onClick={handlePropose}
              disabled={isLoading}
              className="w-full bg-blue-600 text-white p-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
            >
              {isLoading ? "Proposing..." : "2. Create Proposal (Gasless)"}
            </button>
          </>
        )}

        {status && (
          <div className="p-3 bg-white border border-blue-300 text-blue-800 rounded">
            {status}
          </div>
        )}
      </div>
    </div>
  );
}
```

**components/EIP7702Vote.tsx**

```typescript
"use client";

import { useState } from "react";
import { useAccount, useWalletClient, usePublicClient } from "wagmi";
import { encodeFunctionData } from "viem";
import { signAuthorization } from "viem/experimental";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

export function EIP7702Vote() {
  const { address } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [proposalId, setProposalId] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState("");
  const [authorization, setAuthorization] = useState<any>(null);

  const handleAuthorize = async () => {
    if (!walletClient) return;

    setIsLoading(true);
    setStatus("Signing authorization...");

    try {
      const auth = await signAuthorization(walletClient, {
        contractAddress: GOV_CONTRACT_ADDRESS as `0x${string}`,
      });

      setAuthorization(auth);
      setStatus("Authorization signed! You can now vote gaslessly.");
    } catch (error) {
      console.error(error);
      setStatus("Error signing authorization");
    } finally {
      setIsLoading(false);
    }
  };

  const handleVote = async (support: 0 | 1 | 2) => {
    if (!walletClient || !authorization || !proposalId) return;

    setIsLoading(true);
    setStatus("Casting vote...");

    try {
      const data = encodeFunctionData({
        abi: GOV_ABI,
        functionName: "castVote",
        args: [BigInt(proposalId), support],
      });

      const hash = await walletClient.sendTransaction({
        to: GOV_CONTRACT_ADDRESS as `0x${string}`,
        data,
        authorizationList: [authorization],
      });

      await publicClient?.waitForTransactionReceipt({ hash });
      setStatus("Vote cast successfully! You paid ZERO gas.");
    } catch (error) {
      console.error(error);
      setStatus("Error casting vote");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="p-6 border rounded-lg bg-blue-50">
      <h2 className="text-2xl font-bold mb-4">Vote (EIP-7702)</h2>
      <p className="text-sm text-blue-700 mb-4">
        ⚡ Native account abstraction - Simplest gasless method!
      </p>

      <div className="space-y-4">
        {!authorization && (
          <button
            onClick={handleAuthorize}
            disabled={isLoading}
            className="w-full bg-blue-600 text-white p-2 rounded hover:bg-blue-700 disabled:bg-gray-400"
          >
            {isLoading ? "Authorizing..." : "1. Sign Authorization"}
          </button>
        )}

        {authorization && (
          <>
            <div className="p-3 bg-green-100 text-green-800 rounded text-sm">
              Authorization signed! You can now vote without gas.
            </div>

            <input
              type="text"
              placeholder="Proposal ID"
              value={proposalId}
              onChange={(e) => setProposalId(e.target.value)}
              className="w-full p-2 border rounded mb-4"
            />

            <div className="flex gap-2 mb-4">
              <button
                onClick={() => handleVote(0)}
                disabled={isLoading}
                className="flex-1 bg-red-500 text-white p-2 rounded hover:bg-red-600"
              >
                Against
              </button>

              <button
                onClick={() => handleVote(1)}
                disabled={isLoading}
                className="flex-1 bg-green-500 text-white p-2 rounded hover:bg-green-600"
              >
                For
              </button>

              <button
                onClick={() => handleVote(2)}
                disabled={isLoading}
                className="flex-1 bg-gray-500 text-white p-2 rounded hover:bg-gray-600"
              >
                Abstain
              </button>
            </div>
          </>
        )}

        {status && (
          <div className="p-3 bg-white border border-blue-300 text-blue-800 rounded">
            {status}
          </div>
        )}
      </div>
    </div>
  );
}
```

**Update app/governance/page.tsx to include EIP-7702:**

```typescript
import { TraditionalPropose } from "@/components/TraditionalPropose";
import { TraditionalVote } from "@/components/TraditionalVote";
import { GaslessPropose } from "@/components/GaslessPropose";
import { GaslessVote } from "@/components/GaslessVote";
import { EIP7702Propose } from "@/components/EIP7702Propose";
import { EIP7702Vote } from "@/components/EIP7702Vote";

export default function GovernancePage() {
  return (
    <div className="container mx-auto p-8">
      <h1 className="text-4xl font-bold mb-8">DAO Governance</h1>

      <div className="mb-8 p-4 bg-blue-100 rounded">
        <h2 className="text-xl font-bold mb-2">Recommended: EIP-7702</h2>
        <p className="text-sm text-gray-700">
          Native account abstraction - simplest and most efficient gasless method
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
        <EIP7702Propose />
        <GaslessPropose />
        <TraditionalPropose />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <EIP7702Vote />
        <GaslessVote />
        <TraditionalVote />
      </div>
    </div>
  );
}
```

---

### Real-time Updates with Polling

**hooks/useProposalState.ts**

```typescript
import { useEffect, useState } from "react";
import { usePublicClient } from "wagmi";
import { ethers } from "ethers";
import { GOV_CONTRACT_ADDRESS, GOV_ABI } from "@/lib/contracts";

export function useProposalState(proposalId: string) {
  const [state, setState] = useState<number | null>(null);
  const publicClient = usePublicClient();

  useEffect(() => {
    if (!proposalId || !publicClient) return;

    const checkState = async () => {
      const provider = new ethers.BrowserProvider(publicClient as any);
      const contract = new ethers.Contract(GOV_CONTRACT_ADDRESS, GOV_ABI, provider);
      const currentState = await contract.state(proposalId);
      setState(Number(currentState));
    };

    checkState();
    const interval = setInterval(checkState, 10000); // Poll every 10 seconds

    return () => clearInterval(interval);
  }, [proposalId, publicClient]);

  const stateNames = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"];

  return {
    state,
    stateName: state !== null ? stateNames[state] : "Unknown",
  };
}
```

---

## Security Considerations

### UserOperation Security

1. **Nonce Protection**: Each UserOp increments the user's nonce, preventing replay attacks
2. **Signature Verification**: Only the member can sign valid UserOperations
3. **Membership Check**: Only NFT holders can execute UserOperations
4. **Gas Limits**: Each UserOp specifies gas limits to prevent DoS
5. **Chain-specific**: UserOpHash includes chainId and contract address

### Traditional Transaction Security

1. Standard Ethereum transaction security
2. Governor access control (onlyGovernance for sensitive functions)
3. Proposal lifecycle state machine prevents invalid state transitions

---

## Gas Tracking

When using UserOperations, the DAO can monitor gas usage per member:

```javascript
// Check how much gas a member has consumed
const gasUsed = await govContract.gasSpent(memberAddress);
console.log(`Member has used ${gasUsed} gas units`);
```

This allows the DAO to:

- Monitor treasury usage
- Set spending limits per member
- Analyze governance participation costs
- Make data-driven decisions about sponsorship

---

## Best Practices

### When to use Traditional Method

- User already has ETH
- Simple, one-off interactions
- No need for gas abstraction
- Lower integration complexity

### When to use UserOperations

- Onboarding new members without ETH
- Building inclusive DAOs
- Meta-transaction services
- Batch operations via relayers
- Mobile-first applications

### Relayer Services

Consider building or integrating with a relayer service that:

- Accepts signed UserOperations
- Submits them on behalf of users
- Gets reimbursed by DAO treasury
- Provides APIs for easy integration

---

## Testing

See [GovSponsor.t.sol](../test/unit/GovSponsor.t.sol) for comprehensive tests including:

- Traditional workflow (`propose` → `castVote` → `execute`)
- Gasless workflow (all operations via UserOps)
- Security tests (invalid signatures, non-members, nonce replay)
- Gas tracking verification
- Membership verification

---

## References

- **Gov Contract**: [src/Gov.sol](../src/Gov.sol)
- **GovSponsor Extension**: [src/extensions/GovSponsor.sol](../src/extensions/GovSponsor.sol)
- **Tests**: [test/unit/GovSponsor.t.sol](../test/unit/GovSponsor.t.sol)
- **OpenZeppelin Governor**: https://docs.openzeppelin.com/contracts/governance
- **EIP-4337 (Account Abstraction)**: https://eips.ethereum.org/EIPS/eip-4337
