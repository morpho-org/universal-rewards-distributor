// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when the merkle tree's root is updated.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootSet(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a new merkle tree's root is submitted.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootProposed(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a merkle tree distribution timelock is modified.
    /// @param timelock The new merkle tree's timelock.
    event TimelockSet(uint256 timelock);

    /// @notice Emitted when a merkle tree updater is added or removed.
    /// @param rootUpdater The merkle tree updater.
    /// @param active The merkle tree updater's active state.
    event RootUpdaterSet(address indexed rootUpdater, bool active);

    /// @notice Emitted when a merkle tree's pending root is revoked.
    event RootRevoked();

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event Claimed(address indexed account, address indexed reward, uint256 amount);

    /// @notice Emitted when the ownership of a merkle tree distribution is transferred.
    /// @param previousOwner The previous owner of the merkle tree distribution.
    /// @param newOwner The new owner of the merkle tree distribution.
    event OwnerSet(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when a new Urd is created.
    /// @param urd The address of the newly created Urd.
    /// @param caller The address of the caller.
    /// @param owner The address of the Urd owner.
    /// @param timelock The Urd timelock.
    /// @param root The Urd merkle tree's root.
    /// @param ipfsHash The Urd merkle tree's ipfs hash.
    /// @param salt The salt used for CREATE2 opcode.
    event UrdCreated(
        address indexed urd,
        address indexed caller,
        address indexed owner,
        uint256 timelock,
        bytes32 root,
        bytes32 ipfsHash,
        bytes32 salt
    );
}
