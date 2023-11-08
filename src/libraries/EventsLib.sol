// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when the merkle root is set.
    /// @param newRoot The new merkle root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootSet(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a new merkle root is proposed.
    /// @param caller The address of the caller.
    /// @param newRoot The new merkle root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event PendingRootSet(address indexed caller, bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when the pending root is revoked by the owner or an updater.
    event PendingRootRevoked(address indexed caller);

    /// @notice Emitted when a merkle tree distribution timelock is set.
    /// @param newTimelock The new merkle timelock.
    event TimelockSet(uint256 newTimelock);

    /// @notice Emitted when a merkle tree updater is added or removed.
    /// @param rootUpdater The merkle tree updater.
    /// @param active The merkle tree updater's active state.
    event RootUpdaterSet(address indexed rootUpdater, bool active);

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimed.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event Claimed(address indexed account, address indexed reward, uint256 amount);

    /// @notice Emitted when the ownership of a merkle tree distribution is transferred.
    /// @param newOwner The new owner of the contract.
    event OwnerSet(address indexed newOwner);

    /// @notice Emitted when a new URD is created.
    /// @param urd The address of the newly created URD.
    /// @param caller The address of the caller.
    /// @param initialOwner The address of the URD owner.
    /// @param initialTimelock The URD timelock.
    /// @param initialRoot The URD's initial merkle root.
    /// @param initialIpfsHash The URD's initial ipfs hash.
    /// @param salt The salt used for CREATE2 opcode.
    event UrdCreated(
        address indexed urd,
        address indexed caller,
        address indexed initialOwner,
        uint256 initialTimelock,
        bytes32 initialRoot,
        bytes32 initialIpfsHash,
        bytes32 salt
    );
}
