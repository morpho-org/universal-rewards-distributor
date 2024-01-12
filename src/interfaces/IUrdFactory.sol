// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IUniversalRewardsDistributor} from "./IUniversalRewardsDistributor.sol";

/// @title IUrdFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of UniversalRewardsDistributor's factory.
interface IUrdFactory {
    /// @notice Whether a UniversalRewardsDistributor was created with the factory.
    function isUrd(address target) external view returns (bool);

    /// @notice Creates a new URD contract using CREATE2 opcode.
    /// @param initialOwner The initial owner of the URD.
    /// @param initialTimelock The initial timelock of the URD.
    /// @param initialRoot The initial merkle root of the URD.
    /// @param initialIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    /// @param salt The salt used for CREATE2 opcode.
    /// @return The address of the newly created URD.
    function createUrd(
        address initialOwner,
        uint256 initialTimelock,
        bytes32 initialRoot,
        bytes32 initialIpfsHash,
        bytes32 salt
    ) external returns (IUniversalRewardsDistributor);
}
