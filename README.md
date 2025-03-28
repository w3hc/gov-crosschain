# Cross-chain Gov [![Open in Gitpod][gitpod-badge]][gitpod] [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: GPL-3.0][license-badge]][license]

A cross-chain DAO governance framework that allows synchronization across multiple EVM networks.

## Overview

Gov-Crosschain enables DAOs to manage operations across multiple blockchains while maintaining consistent governance
parameters, membership, and decisions. The system uses a home chain as the source of truth, with cross-chain proofs to
synchronize state changes to foreign chains.

## Features

- Cross-chain governance parameters synchronization
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

1. Change occurs on home chain through governance
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

- The home chain (Optimism) is the source of truth
- All operations on foreign chains require cryptographic proof verification
- Membership NFTs are non-transferable to maintain governance integrity
- All sensitive operations require governance approval

## License

This project is licensed under the GNU General Public License v3.0.

## Support

Feel free to reach out to [Julien](https://github.com/julienbrg) on [Farcaster](https://warpcast.com/julien-),
[Element](https://matrix.to/#/@julienbrg:matrix.org),
[Status](https://status.app/u/iwSACggKBkp1bGllbgM=#zQ3shmh1sbvE6qrGotuyNQB22XU5jTrZ2HFC8bA56d5kTS2fy),
[Telegram](https://t.me/julienbrg), [Twitter](https://twitter.com/julienbrg),
[Discord](https://discordapp.com/users/julienbrg), or [LinkedIn](https://www.linkedin.com/in/julienberanger/).
