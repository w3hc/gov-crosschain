#!/bin/bash

# Clean up any previous build artifacts
echo "Cleaning build artifacts..."
rm -rf cache out

# Rebuild the project
echo "Rebuilding project..."
forge build

# Check for any references to Foo.sol in the codebase
echo "Checking for references to Foo.sol..."
grep -r "Foo.sol" --include="*.sol" .

echo "Done!"
