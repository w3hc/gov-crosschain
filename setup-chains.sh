#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Safe Singleton Factory deployment data
SAFE_FACTORY_DEPLOYER="0xE1CB04A0fA36DdD16a06ea828007E35e1a3cBC37"
SAFE_FACTORY_TX="0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"

# Cleanup function to stop all chains
cleanup() {
    echo ""
    echo "All chains stopped"
    kill $(jobs -p) 2>/dev/null
    exit 0
}

# Set up trap to catch Ctrl+C
trap cleanup SIGINT SIGTERM

# Function to deploy Safe Singleton Factory
deploy_safe_factory() {
    local rpc_url=$1
    local chain_name=$2

    # Fund the deployer address
    cast send --rpc-url "$rpc_url" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        "$SAFE_FACTORY_DEPLOYER" --value 1ether > /dev/null 2>&1

    # Deploy using the presigned transaction
    cast publish --rpc-url "$rpc_url" "$SAFE_FACTORY_TX" > /dev/null 2>&1
}

# Start chains in background (no forking)
# Use Anvil's default chain ID (31337) for local development to avoid triggering mainnet checks
# Set gas price to match Safe Singleton Factory presigned tx (100 gwei)
echo "Starting Optimism-like chain (Home Chain) on port 8545..."
anvil --port 8545 --chain-id 31337 --block-time 2 --gas-price 100000000000 > /dev/null 2>&1 &
OPTIMISM_PID=$!

echo "Starting Arbitrum-like chain on port 8546..."
anvil --port 8546 --chain-id 31338 --block-time 2 --gas-price 100000000000 > /dev/null 2>&1 &
ARBITRUM_PID=$!

echo "Starting Base-like chain on port 8547..."
anvil --port 8547 --chain-id 31339 --block-time 2 --gas-price 100000000000 > /dev/null 2>&1 &
BASE_PID=$!

# Wait for chains to start
sleep 3

# Check if all chains are running
if ! kill -0 $OPTIMISM_PID 2>/dev/null || ! kill -0 $ARBITRUM_PID 2>/dev/null || ! kill -0 $BASE_PID 2>/dev/null; then
    echo "Error: Failed to start one or more chains"
    cleanup
fi

# Deploy Safe Singleton Factory to all chains
echo "Deploying Safe Singleton Factory to all chains..."
deploy_safe_factory "http://localhost:8545" "Optimism"
deploy_safe_factory "http://localhost:8546" "Arbitrum"
deploy_safe_factory "http://localhost:8547" "Base"

echo -e "${GREEN}All chains are running!${NC}"
echo ""
echo -e "${BLUE}Chain Configuration:${NC}"
echo "  Optimism-like (Home Chain): http://localhost:8545 (Chain ID: 31337)"
echo "  Arbitrum-like:              http://localhost:8546 (Chain ID: 31338)"
echo "  Base-like:                  http://localhost:8547 (Chain ID: 31339)"
echo ""
echo -e "${BLUE}Safe Singleton Factory:${NC} Deployed to all chains at 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7"
echo ""
echo -e "${GREEN}To deploy factories to all chains, run:${NC}"
echo "  forge script script/DeployFactories.s.sol --rpc-url local_optimism --broadcast"
echo "  forge script script/DeployFactories.s.sol --rpc-url local_arbitrum --broadcast"
echo "  forge script script/DeployFactories.s.sol --rpc-url local_base --broadcast"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all chains${NC}"

# Wait for all background processes
wait
