// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.28;

import { Gov } from "./Gov.sol";
import { NFT } from "./NFT.sol";

/**
 * @title GovFactory
 * @author Web3 Hackers Collective
 * @notice Factory for Gov deployment
 * @custom:security-contact julien@strat.cc
 */
contract GovFactory {
    event GovDeployed(address indexed gov);

    function deployGov(
        uint256 homeChainId,
        bytes32 salt,
        NFT nft,
        string calldata manifestoCid,
        string calldata name,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumPercentage
    )
        external
        returns (address)
    {
        bytes32 govSalt = keccak256(abi.encodePacked(salt, "GOV"));
        address govAddress = address(
            new Gov{ salt: govSalt }(
                homeChainId, nft, manifestoCid, name, votingDelay, votingPeriod, proposalThreshold, quorumPercentage
            )
        );

        NFT(nft).transferOwnership(govAddress);

        emit GovDeployed(govAddress);
        return govAddress;
    }
}
