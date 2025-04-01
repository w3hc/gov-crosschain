// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { NFTFactory } from "../src/NFTFactory.sol";
import { GovFactory } from "../src/GovFactory.sol";

/**
 * @title DeployFactories
 * @notice Deploys the GovFactory and NFTFactory contracts using the Safe Singleton Factory
 */
contract DeployFactories is Script {
    // Safe Singleton Factory address - same on all EVM chains
    address constant SAFE_SINGLETON_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    // Salt for CREATE2 deployment
    bytes32 constant SALT = bytes32(uint256(0x1234));

    // Use Anvil's default private key for Alice
    uint256 private constant ALICE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public returns (address govFactoryAddress, address nftFactoryAddress) {
        uint256 chainId = block.chainid;
        console2.log("Deploying factories on chain ID:", chainId);
        console2.log("Using Safe Singleton Factory at:", SAFE_SINGLETON_FACTORY);

        // Get the creation code for GovFactory
        bytes memory govFactoryCreationCode = type(GovFactory).creationCode;
        console2.log("GovFactory creation code length:", govFactoryCreationCode.length, "bytes");

        // Compute the expected address for GovFactory
        address expectedGovFactory = calculateCreate2Address(SALT, keccak256(govFactoryCreationCode));
        console2.log("Expected GovFactory address:", expectedGovFactory);

        // Use the hardcoded private key instead of the default broadcaster
        vm.startBroadcast(ALICE_KEY);

        // Step 1: Deploy GovFactory using Safe Singleton Factory
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
        (bool nftSuccess, bytes memory nftReturnData) =
            SAFE_SINGLETON_FACTORY.call(abi.encodePacked(SALT, nftFactoryCreationCode));

        require(nftSuccess, "NFTFactory deployment failed");

        // Parse the returned address
        nftFactoryAddress = bytesToAddress(nftReturnData);
        console2.log("NFTFactory deployed at:", nftFactoryAddress);

        // Verify the NFTFactory setup
        console2.log("Verifying NFTFactory setup:");
        console2.log("NFTFactory's GovFactory reference:", NFTFactory(nftFactoryAddress).GOV_FACTORY());

        vm.stopBroadcast();

        console2.log("\nNext steps:");
        console2.log("1. Deploy these same factories on the other chain using the same command");
        console2.log("2. Use 'DeployWithFactory.s.sol' to deploy your DAO contracts on both chains");
        console2.log("3. Update DeployWithFactory.s.sol with these factory addresses:");
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
        assembly {
            addr := mload(add(data, 20))
        }
        return addr;
    }
}
