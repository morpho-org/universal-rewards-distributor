// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {UniversalRewardsDistributor} from "./UniversalRewardsDistributor.sol";
import {FactoryEventsLib} from "./libraries/FactoryEventsLib.sol";


/// @title Universal Rewards Distributor Factory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract permits to create UniversalRewardsDistributor contracts, and to index them easily.
contract URDFactory {
    /// @notice Creates a new URD contract using CREATE2 opcode.
    /// @param initialOwner The initial owner of the URD.
    /// @param initialTimelock The initial timelock of the URD.
    /// @param initialRoot The initial merkle tree's root of the URD.
    /// @param initialIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    /// @param salt The salt used for CREATE2 opcode.
    /// @return urd The address of the newly created URD.
    function createURD(
        address initialOwner,
        uint256 initialTimelock,
        bytes32 initialRoot,
        bytes32 initialIpfsHash,
        bytes32 salt
    ) public returns (address urd) {
        urd = address(
            new UniversalRewardsDistributor{salt: salt}(
            initialOwner,
            initialTimelock,
            initialRoot,
            initialIpfsHash
            )
        );
        emit FactoryEventsLib.URDCreated(
            urd, msg.sender, initialOwner, initialTimelock, initialRoot, initialIpfsHash, salt
        );
    }
}
