// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.29 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import { BaseScript } from "./Base.s.sol";
import { NFTFactory } from "../src/NFTFactory.sol";
import { GovFactory } from "../src/GovFactory.sol";

/**
 * @title DeployFactories
 * @notice Deploys the GovFactory and NFTFactory contracts using the Safe Singleton Factory
 * @dev Supports local, testnet, and mainnet deployments with appropriate security measures
 *
 * Usage:
 *   Local:   forge script script/DeployFactories.s.sol --rpc-url http://localhost:8545 --broadcast
 *   Testnet: forge script script/DeployFactories.s.sol --rpc-url $TESTNET_RPC_URL --broadcast --verify
 *   Mainnet: forge script script/DeployFactories.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify --slow
 *
 * Environment Variables:
 *   PRIVATE_KEY: Private key for testnet/mainnet deployments (recommended)
 *   ETH_FROM: Alternative to PRIVATE_KEY (uses address directly)
 *   MNEMONIC: Fallback for testnet only (not recommended)
 */
contract DeployFactories is BaseScript {
    // Safe Singleton Factory address - same on all EVM chains
    address private constant SAFE_SINGLETON_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    // Salt for CREATE2 deployment - can be customized per environment
    bytes32 private constant SALT = bytes32(uint256(0x1234));

    function run() public returns (address govFactoryAddress, address nftFactoryAddress) {
        uint256 chainId = block.chainid;
        console2.log("\n================================");
        console2.log("Deploying Factories");
        console2.log("================================");
        console2.log("Chain ID:", chainId);
        console2.log("Deployer:", broadcaster);
        console2.log("Salt:", vm.toString(SALT));
        console2.log("================================\n");

        // Mainnet safety check
        if (isMainnet()) {
            console2.log("WARNING: You are deploying to MAINNET");
            console2.log("Please verify all parameters carefully!");
            console2.log("Deployer address:", broadcaster);
            uint256 balance = broadcaster.balance;
            console2.log("Deployer balance:", balance);
            require(balance > 0.1 ether, "Low balance for mainnet");
        }

        // Check if Safe Singleton Factory is deployed
        address safeSingletonFactory = SAFE_SINGLETON_FACTORY;
        uint256 codeSize;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codeSize := extcodesize(safeSingletonFactory)
        }

        // Check if we should use regular CREATE2 for local deployment
        bool useRegularCreate2 = isLocal() && codeSize == 0;

        if (useRegularCreate2) {
            console2.log("Local deployment detected - using regular CREATE2 deployment");
        } else if (codeSize == 0) {
            revert("Safe Singleton Factory missing");
        } else {
            console2.log("Using existing Safe Singleton Factory at:", SAFE_SINGLETON_FACTORY);
        }

        // Use broadcastWithKey modifier from BaseScript
        vm.startBroadcast(getPrivateKey());

        if (useRegularCreate2) {
            // Deploy using regular CREATE2 for local development
            console2.log("\n=== Local CREATE2 Deployment ===");

            bytes32 salt = SALT; // Load constant into local variable for assembly

            // Step 1: Deploy GovFactory using CREATE2
            bytes memory govFactoryCreationCode = type(GovFactory).creationCode;
            console2.log("GovFactory creation code length:", govFactoryCreationCode.length, "bytes");

            address computedGovAddress;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                computedGovAddress := create2(0, add(govFactoryCreationCode, 0x20), mload(govFactoryCreationCode), salt)
            }
            require(computedGovAddress != address(0), "GovFactory deployment failed");
            govFactoryAddress = computedGovAddress;
            console2.log("GovFactory deployed at:", govFactoryAddress);

            // Step 2: Deploy NFTFactory using CREATE2
            bytes memory nftFactoryCreationCode =
                abi.encodePacked(type(NFTFactory).creationCode, abi.encode(govFactoryAddress));
            console2.log("NFTFactory creation code length:", nftFactoryCreationCode.length, "bytes");

            address computedNftAddress;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                computedNftAddress := create2(0, add(nftFactoryCreationCode, 0x20), mload(nftFactoryCreationCode), salt)
            }
            require(computedNftAddress != address(0), "NFTFactory deployment failed");
            nftFactoryAddress = computedNftAddress;
            console2.log("NFTFactory deployed at:", nftFactoryAddress);
        } else {
            // Use Safe Singleton Factory for production deployments
            console2.log("\n=== Safe Singleton Factory Deployment ===");

            // Get the creation code for GovFactory
            bytes memory govFactoryCreationCode = type(GovFactory).creationCode;
            console2.log("GovFactory creation code length:", govFactoryCreationCode.length, "bytes");

            // Compute the expected address for GovFactory
            address expectedGovFactory = calculateCreate2Address(SALT, keccak256(govFactoryCreationCode));
            console2.log("Expected GovFactory address:", expectedGovFactory);

            // Step 1: Deploy GovFactory using Safe Singleton Factory
            // solhint-disable-next-line avoid-low-level-calls
            (bool govSuccess, bytes memory govReturnData) =
                SAFE_SINGLETON_FACTORY.call(abi.encodePacked(SALT, govFactoryCreationCode));

            require(govSuccess, "GovFactory deployment failed");

            // Parse the returned address
            govFactoryAddress = bytesToAddress(govReturnData);
            console2.log("GovFactory deployed at:", govFactoryAddress);

            // Step 2: Prepare NFTFactory creation code with the GovFactory address
            bytes memory nftFactoryCreationCode =
                abi.encodePacked(type(NFTFactory).creationCode, abi.encode(govFactoryAddress));
            console2.log("NFTFactory creation code length:", nftFactoryCreationCode.length, "bytes");

            // Compute the expected address for NFTFactory
            address expectedNftFactory = calculateCreate2Address(SALT, keccak256(nftFactoryCreationCode));
            console2.log("Expected NFTFactory address:", expectedNftFactory);

            // Deploy NFTFactory using Safe Singleton Factory
            // solhint-disable-next-line avoid-low-level-calls
            (bool nftSuccess, bytes memory nftReturnData) =
                SAFE_SINGLETON_FACTORY.call(abi.encodePacked(SALT, nftFactoryCreationCode));

            require(nftSuccess, "NFTFactory deployment failed");

            // Parse the returned address
            nftFactoryAddress = bytesToAddress(nftReturnData);
            console2.log("NFTFactory deployed at:", nftFactoryAddress);
        }

        // Verify the NFTFactory setup
        console2.log("Verifying NFTFactory setup:");
        console2.log("NFTFactory's GovFactory reference:", NFTFactory(nftFactoryAddress).GOV_FACTORY());

        vm.stopBroadcast();

        console2.log("\n================================");
        console2.log("Deployment Summary");
        console2.log("================================");
        console2.log("Environment:", isLocal() ? "LOCAL" : isTestnet() ? "TESTNET" : "MAINNET");
        console2.log("Chain ID:", chainId);
        console2.log("GovFactory:", govFactoryAddress);
        console2.log("NFTFactory:", nftFactoryAddress);
        console2.log("================================");

        console2.log("\nNext steps:");
        if (!isMainnet()) {
            console2.log("1. Deploy these same factories on the other chain using the same command");
            console2.log("2. Use 'DeployDAO.s.sol' to deploy your DAO contracts on both chains");
            console2.log("3. Update DeployDAO.s.sol with these factory addresses:");
        } else {
            console2.log("1. Verify contracts on Etherscan");
            console2.log("2. Update production configuration with factory addresses:");
        }
        console2.log("   govFactoryAddress = %s;", govFactoryAddress);
        console2.log("   nftFactoryAddress = %s;", nftFactoryAddress);

        return (govFactoryAddress, nftFactoryAddress);
    }

    function calculateCreate2Address(bytes32 salt, bytes32 bytecodeHash) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), SAFE_SINGLETON_FACTORY, salt, bytecodeHash))))
        );
    }

    function bytesToAddress(bytes memory data) internal pure returns (address) {
        require(data.length == 20, "Invalid address length");
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr := mload(add(data, 20))
        }
        return addr;
    }
}
