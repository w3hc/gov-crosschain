#!/bin/bash

# This script sets up multiple anvil instances for cross-chain testing

# Kill any existing anvil processes
pkill -f anvil

# Start Optimism chain (Home Chain)
echo "Starting Optimism chain (Home Chain) on port 8545..."
anvil --chain-id 10 --port 8545 --block-time 2 > /tmp/anvil-optimism.log 2>&1 &
OPTIMISM_PID=$!

# Wait for chain to start
sleep 2

# Start Arbitrum chain
echo "Starting Arbitrum chain on port 8546..."
anvil --chain-id 42161 --port 8546 --block-time 2 > /tmp/anvil-arbitrum.log 2>&1 &
ARBITRUM_PID=$!

# Wait for chain to start
sleep 2

# Start Base chain
echo "Starting Base chain on port 8547..."
anvil --chain-id 8453 --port 8547 --block-time 2 > /tmp/anvil-base.log 2>&1 &
BASE_PID=$!

echo "All chains are running!"
echo "Optimism (Home Chain): http://localhost:8545"
echo "Arbitrum: http://localhost:8546"
echo "Base: http://localhost:8547"
echo ""
echo "To deploy to all chains, run:"
echo "forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast"
echo "forge script script/Deploy.s.sol --rpc-url http://localhost:8546 --broadcast"
echo "forge script script/Deploy.s.sol --rpc-url http://localhost:8547 --broadcast"
echo ""
echo "To stop all chains, press Ctrl+C"

# Wait for user to press Ctrl+C
trap "kill $OPTIMISM_PID $ARBITRUM_PID $BASE_PID; echo 'All chains stopped'; exit 0" INT
wait
