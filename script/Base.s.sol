// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.29 <0.9.0;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev Use Anvil's default private key for local development (Alice)
    uint256 private constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    /// @dev Chain IDs for environment detection
    // Local development chains (Anvil)
    uint256 private constant ANVIL_CHAIN_ID = 31_337;
    uint256 private constant ANVIL_CHAIN_ID_2 = 31_338; // Second local chain
    uint256 private constant ANVIL_CHAIN_ID_3 = 31_339; // Third local chain

    // Testnet chains
    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 private constant OPTIMISM_SEPOLIA_CHAIN_ID = 11_155_420;
    uint256 private constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint256 private constant ARBITRUM_SEPOLIA_CHAIN_ID = 421_614;

    // Mainnet chains
    uint256 private constant ETHEREUM_MAINNET_CHAIN_ID = 1;
    uint256 private constant OPTIMISM_MAINNET_CHAIN_ID = 10;
    uint256 private constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 private constant ARBITRUM_MAINNET_CHAIN_ID = 42_161;

    /// @dev Environment types
    enum Environment {
        Local,
        Testnet,
        Mainnet
    }

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    /// @dev The current environment
    Environment internal environment;

    /// @dev Initializes the transaction broadcaster and determines the environment
    ///
    /// - Detects environment based on chain ID
    /// - For local: Uses Anvil default key
    /// - For testnet/mainnet: Uses $PRIVATE_KEY, $ETH_FROM, or $MNEMONIC
    ///
    /// Security: Requires explicit environment variable for testnet/mainnet deployments
    constructor() {
        environment = getEnvironment();

        if (environment == Environment.Local) {
            // For local development, use Anvil's default key
            broadcaster = vm.addr(ANVIL_DEFAULT_KEY);
            console2.log("Environment: LOCAL");
            console2.log("Using Anvil default broadcaster:", broadcaster);
        } else {
            // For testnet/mainnet, require environment variables
            console2.log("Environment:", environment == Environment.Testnet ? "TESTNET" : "MAINNET");

            // Try PRIVATE_KEY first (most secure for production)
            try vm.envUint("PRIVATE_KEY") returns (uint256 privateKey) {
                broadcaster = vm.addr(privateKey);
                console2.log("Using PRIVATE_KEY broadcaster:", broadcaster);
            } catch {
                // Fall back to ETH_FROM
                address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
                if (from != address(0)) {
                    broadcaster = from;
                    console2.log("Using ETH_FROM broadcaster:", broadcaster);
                } else {
                    // Fall back to MNEMONIC (least secure, not recommended for mainnet)
                    if (environment == Environment.Mainnet) {
                        revert("MAINNET: need PK or ETH_FROM");
                    }
                    mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
                    (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
                    console2.log("Using MNEMONIC broadcaster:", broadcaster);
                }
            }
        }
    }

    /// @dev Determines the environment based on chain ID
    function getEnvironment() internal view returns (Environment) {
        uint256 chainId = block.chainid;

        // Local chains (Anvil instances)
        if (chainId == ANVIL_CHAIN_ID || chainId == ANVIL_CHAIN_ID_2 || chainId == ANVIL_CHAIN_ID_3) {
            return Environment.Local;
        }

        // Testnets
        if (
            chainId == SEPOLIA_CHAIN_ID || chainId == OPTIMISM_SEPOLIA_CHAIN_ID || chainId == BASE_SEPOLIA_CHAIN_ID
                || chainId == ARBITRUM_SEPOLIA_CHAIN_ID
        ) {
            return Environment.Testnet;
        }

        // Mainnets
        if (
            chainId == ETHEREUM_MAINNET_CHAIN_ID || chainId == OPTIMISM_MAINNET_CHAIN_ID
                || chainId == BASE_MAINNET_CHAIN_ID || chainId == ARBITRUM_MAINNET_CHAIN_ID
        ) {
            return Environment.Mainnet;
        }

        // Default to testnet for unknown chains (safer than mainnet)
        console2.log("WARNING: Unknown chain ID, treating as testnet:", chainId);
        return Environment.Testnet;
    }

    /// @dev Returns true if deploying to mainnet
    function isMainnet() internal view returns (bool) {
        return environment == Environment.Mainnet;
    }

    /// @dev Returns true if deploying to testnet
    function isTestnet() internal view returns (bool) {
        return environment == Environment.Testnet;
    }

    /// @dev Returns true if deploying to local environment
    function isLocal() internal view returns (bool) {
        return environment == Environment.Local;
    }

    /// @dev Gets the appropriate private key based on environment
    function getPrivateKey() internal view returns (uint256) {
        if (environment == Environment.Local) {
            return ANVIL_DEFAULT_KEY;
        } else {
            // For testnet/mainnet, this should come from env
            return vm.envUint("PRIVATE_KEY");
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    modifier broadcastWithKey() {
        uint256 privateKey = getPrivateKey();
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }
}
