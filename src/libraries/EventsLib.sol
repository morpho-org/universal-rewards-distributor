// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when the Merkle root is set.
    /// @param newRoot The new Merkle root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the Merkle tree itself).
    event RootSet(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a new Merkle root is proposed.
    /// @param newRoot The new Merkle root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the Merkle tree itself).
    event PendingRootSet(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a Merkle tree distribution timelock is set.
    /// @param timelock The new Merkle timelock.
    event TimelockSet(uint256 timelock);

    /// @notice Emitted when a Merkle tree updater is added or removed.
    /// @param rootUpdater The Merkle tree updater.
    /// @param active The Merkle tree updater's active state.
    event RootUpdaterSet(address indexed rootUpdater, bool active);

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event Claimed(address indexed account, address indexed reward, uint256 amount);

    /// @notice Emitted when the ownership of a Merkle tree distribution is transferred.
    /// @param newOwner The new owner of the contract.
    event OwnerSet(address indexed newOwner);

    /// @notice Emitted when a new URD is created.
    /// @param urd The address of the newly created URD.
    /// @param caller The address of the caller.
    /// @param owner The address of the URD owner.
    /// @param timelock The URD timelock.
    /// @param root The URD's initial Merkle root.
    /// @param ipfsHash The URD's initial ipfs hash.
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
