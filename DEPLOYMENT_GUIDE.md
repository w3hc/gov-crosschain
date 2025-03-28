# Cross-Chain Governance Deployment Guide

This guide will walk you through deploying and testing the cross-chain governance framework across multiple chains.

## Prerequisites

Make sure you have these tools installed:

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Bun](https://bun.sh/)

## Setup

1. First, install dependencies:

```bash
bun install
```

2. Build the contracts:

```bash
forge build
```

## Running Test Chains

1. Make the setup script executable:

```bash
chmod +x setup-chains.sh
```

2. Run the script to start three Anvil instances (Optimism, Arbitrum, Base):

```bash
./setup-chains.sh
```

This will start three separate Anvil instances:

- Optimism (Home Chain): http://localhost:8545 (Chain ID: 10)
- Arbitrum: http://localhost:8546 (Chain ID: 42161)
- Base: http://localhost:8547 (Chain ID: 8453)

## Deployment

Now you need to deploy the contracts to all three chains:

1. Deploy to Optimism (Home Chain):

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

2. Deploy to Arbitrum:

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8546 --broadcast
```

3. Deploy to Base:

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8547 --broadcast
```

Save the contract addresses from each deployment. You'll need them for testing.

## Cross-Chain Testing

After deployment, you can test cross-chain functionality:

1. Update the contract addresses in `test-cross-chain.js`

2. Install ethers.js:

```bash
bun add ethers@5.7.2
```

3. Run the test script:

```bash
bun test-cross-chain.js
```

This will:

- Update the manifesto on the home chain
- Generate a proof of the update
- Apply the proof to the other chains
- Add a new member on the home chain
- Generate a proof of the membership
- Apply the proof to the other chains

## How It Works

1. **Home Chain as Source of Truth**: All governance decisions happen on the home chain (Optimism).

2. **Cross-Chain Synchronization**: Changes are synchronized to foreign chains using proofs.

3. **Proof System**: For any parameter change:
   - The change is made on the home chain
   - A proof is generated (cryptographic signature)
   - The proof is submitted to the foreign chains
   - Foreign chains verify and apply the change

## Important Operations

### Governance Parameters

- **Manifesto**: The DAO's founding document/principles
- **Voting Delay**: Time before voting on a proposal begins
- **Voting Period**: Duration of the voting window
- **Proposal Threshold**: Minimum votes needed to create a proposal
- **Quorum**: Minimum participation required for a valid vote

### Membership Management

- **Minting**: Add new members on the home chain
- **Burning**: Remove members on the home chain
- **Metadata Updates**: Update token metadata

### Cross-Chain Operations

- **Generate Proofs**: Create cryptographic proofs of changes
- **Claim Updates**: Apply changes on foreign chains

## Security Considerations

1. **Home Chain Security**: The home chain is the source of truth, so its security is paramount.

2. **Proof Verification**: All operations on foreign chains validate proofs before applying changes.

3. **Non-Transferable Membership**: Membership NFTs cannot be transferred, only minted and burned.

4. **Chain ID Validation**: Operations are restricted to appropriate chains.

## Troubleshooting

If you encounter issues:

1. **RPC Connection**: Make sure all Anvil instances are running.

2. **Contract Addresses**: Verify you're using the correct contract addresses.

3. **Chain IDs**: Confirm you're on the right chain for each operation.

4. **Logs**: Check the Anvil logs for transaction errors.
