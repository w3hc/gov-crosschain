# Cross-chain Gov

A cross-chain DAO framework that allows synchronization across multiple EVM networks.

- [Gov contracts (Hardhat)](https://github.com/w3hc/gov)
- [Documentation](https://w3hc.github.io/gov-docs/)
- [Gov UI](https://gov-ui.netlify.app/)
- [Gov UI repo](https://github.com/w3hc/gov-ui)
- [Gov Deployer](https://gov-deployer.netlify.app/)
- [Gov Deployer repo](https://github.com/w3hc/gov-deployer)
- [Example DAO on Tally](https://www.tally.xyz/gov/web3-hackers-collective)

## Overview

Cross-chain Gov enables DAOs to manage operations across multiple blockchains while maintaining consistent governance
parameters, membership, and decisions. The system uses a home chain as the source of truth, with cross-chain proofs to
synchronize state changes to foreign chains.

## Motivation

Provide a coordination tool that fits the needs of regular users.

## Features

- Synchronization of cross-chain governance parameters
- Non-transferable membership NFTs with voting capabilities
- DAO manifesto management across chains
- Secure proof generation and verification for cross-chain operations

## Install

```bash
bun i
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Deploy locally

Run the `setup-chains.sh` script:

```bash
chmod +x setup-chains.sh
./setup-chains.sh
```

Then deploy the factories:

```bash
forge script script/DeployFactories.s.sol --rpc-url local_optimism --broadcast
```

Change the factories contract addresses in `script/DeployDAO.s.sol` and deploy your DAO:

```bash
forge script script/DeployDAO.s.sol --rpc-url local_optimism --broadcast
```

Propose:

```bash
cast send <GOV_CONTRACT_ADDRESS> \
  "propose(address[],uint256[],bytes[],string)" \
  "[<GOV_CONTRACT_ADDRESS>]" \
  "[0]" \
  "[$(cast calldata "setManifesto(string)" "QmNewManifestoCID")]" \
  "New CID" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url local_optimism
```

Get proposal ID:

```bash
cast call <GOV_CONTRACT_ADDRESS> "proposalIds(uint256)" 0 --rpc-url local_optimism
```

## Support

You can reach out to [Julien](https://github.com/julienbrg) on [Farcaster](https://warpcast.com/julien-),
[Element](https://matrix.to/#/@julienbrg:matrix.org),
[Status](https://status.app/u/iwSACggKBkp1bGllbgM=#zQ3shmh1sbvE6qrGotuyNQB22XU5jTrZ2HFC8bA56d5kTS2fy),
[Telegram](https://t.me/julienbrg), [Twitter](https://twitter.com/julienbrg),
[Discord](https://discordapp.com/users/julienbrg), or [LinkedIn](https://www.linkedin.com/in/julienberanger/).

## Credits

I want to thank [Paul Razvan Berg](https://github.com/paulrberg) for his work on the
[Foundry template](https://github.com/PaulRBerg/foundry-template) we used.

## License

GPL-3.0

<img src="https://bafkreid5xwxz4bed67bxb2wjmwsec4uhlcjviwy7pkzwoyu5oesjd3sp64.ipfs.w3s.link" alt="built-with-ethereum-w3hc" width="100"/>
