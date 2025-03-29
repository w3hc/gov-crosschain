# Cross-chain Gov

A cross-chain DAO framework that allows synchronization across multiple EVM networks.

## Overview

Cross-chain Gov enables DAOs to manage operations across multiple blockchains while maintaining consistent governance
parameters, membership, and decisions. The system uses a home chain as the source of truth, with cross-chain proofs to
synchronize state changes to foreign chains.

## Motivation

Provide a coordination tool that fits the needs of regular users.

- [Gov contracts (Hardhat)](https://github.com/w3hc/gov)
- [Documentation](https://w3hc.github.io/gov-docs/)
- [Gov UI](https://gov-ui.netlify.app/)
- [Gov UI repo](https://github.com/w3hc/gov-ui)
- [Gov Deployer](https://gov-deployer.netlify.app/)
- [Gov Deployer repo](https://github.com/w3hc/gov-deployer)
- [Example DAO on Tally](https://www.tally.xyz/gov/web3-hackers-collective)

## Features

- Synchronization of cross-chain governance parameters
- Non-transferable membership NFTs with voting capabilities
- DAO manifesto management across chains
- Secure proof generation and verification for cross-chain operations

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Bun](https://bun.sh/)

### Installation

```bash
# Clone the repository
git clone https://github.com/w3hc/gov-crosschain.git
cd gov-crosschain

# Install dependencies
bun install

# Build the project
forge build
```

## Testing

Run the basic test suite:

```bash
forge test
```

## Deployment

### Deploy to anvil

```bash
forge script script/DeployWithFactory.s.sol --rpc-url local_optimism --broadcast
```

### Deploy to mainnets

Update your `.env` file with your configuration:

```bash
cp .env.example .env
# Edit .env with your API keys and mnemonic
```

Deploy:

```bash
# Deploy to Optimism
forge script script/Deploy.s.sol --rpc-url optimism --broadcast --verify

# Deploy to Arbitrum
forge script script/Deploy.s.sol --rpc-url arbitrum --broadcast --verify

# Deploy to Base
forge script script/Deploy.s.sol --rpc-url base --broadcast --verify
```

## Usage

1. Deploy the NFT and Governance contracts on your home chain
2. Deploy the same contracts on all foreign chains
3. Use governance to make decisions on the home chain
4. Generate proofs for cross-chain synchronization
5. Apply the proofs on foreign chains to maintain consistency

## Architecture

The system consists of two main contracts:

- **Gov.sol**: Handles governance operations, voting, and parameter management
- **NFT.sol**: Manages DAO membership and voting power

The cross-chain synchronization flow:

1. Changes occur on the home chain through governance
2. Proof is generated for the change
3. Proof is submitted to foreign chains
4. Foreign chains verify and apply the change

## Key Operations

### Governance

- Update DAO manifesto
- Modify voting parameters
- Add/remove members
- Create and vote on proposals

### Cross-Chain Management

- Generate proofs for parameter changes
- Generate proofs for membership changes
- Claim and verify proofs on foreign chains

## Security Considerations

- The home chain (Optimism) serves as the source of truth.
- All operations on foreign chains require cryptographic proof verification
- Membership NFTs are non-transferable to maintain governance integrity
- All sensitive operations require governance approval

## Support

Feel free to reach out to [Julien](https://github.com/julienbrg) on [Farcaster](https://warpcast.com/julien-),
[Element](https://matrix.to/#/@julienbrg:matrix.org),
[Status](https://status.app/u/iwSACggKBkp1bGllbgM=#zQ3shmh1sbvE6qrGotuyNQB22XU5jTrZ2HFC8bA56d5kTS2fy),
[Telegram](https://t.me/julienbrg), [Twitter](https://twitter.com/julienbrg),
[Discord](https://discordapp.com/users/julienbrg), or [LinkedIn](https://www.linkedin.com/in/julienberanger/).

## Credits

I want to thank [Paul Razvan Berg](https://github.com/paulrberg) for his work on the
[Foundry template](https://github.com/PaulRBerg/foundry-template) we used.

## License

This project is licensed under the GNU General Public License v3.0.

<img src="https://bafkreid5xwxz4bed67bxb2wjmwsec4uhlcjviwy7pkzwoyu5oesjd3sp64.ipfs.w3s.link" alt="built-with-ethereum-w3hc" width="100"/>
