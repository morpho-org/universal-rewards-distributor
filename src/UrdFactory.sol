// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {EventsLib} from "./libraries/EventsLib.sol";

import {UniversalRewardsDistributor} from "./UniversalRewardsDistributor.sol";

/// @title Universal Rewards Distributor Factory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract allows to create UniversalRewardsDistributor (URD) contracts, and to index them easily.
contract UrdFactory {
    /* STORAGE */

    mapping(address => bool) public isUrd;

    /* EXTERNAL */

    /// @notice Creates a new URD contract using CREATE2 opcode.
    /// @param initialOwner The initial owner of the URD.
    /// @param initialTimelock The initial timelock of the URD.
    /// @param initialRoot The initial merkle root of the URD.
    /// @param initialIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    /// @param salt The salt used for CREATE2 opcode.
    /// @return urd The address of the newly created URD.
    function createUrd(
        address initialOwner,
        uint256 initialTimelock,
        bytes32 initialRoot,
        bytes32 initialIpfsHash,
        bytes32 salt
    ) public returns (UniversalRewardsDistributor urd) {
        urd = new UniversalRewardsDistributor{salt: salt}(
            initialOwner,
            initialTimelock,
            initialRoot,
            initialIpfsHash
        );

        isUrd[address(urd)] = true;

        emit EventsLib.UrdCreated(
            address(urd), msg.sender, initialOwner, initialTimelock, initialRoot, initialIpfsHash, salt
        );
    }
}
