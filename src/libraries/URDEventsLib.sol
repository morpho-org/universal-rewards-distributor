// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library URDEventsLib {
    /* EVENTS */

    /// @notice Emitted when the merkle tree's root is updated.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootUpdated(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a new merkle tree's root is submitted.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootProposed(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);

    /// @notice Emitted when a merkle tree distribution timelock is modified.
    /// @param timelock The new merkle tree's timelock.
    event TimelockUpdated(uint256 timelock);

    /// @notice Emitted when a merkle tree updater is added or removed.
    /// @param rootUpdater The merkle tree updater.
    /// @param active The merkle tree updater's active state.
    event RootUpdaterUpdated(address indexed rootUpdater, bool active);

    /// @notice Emitted when a merkle tree's pending root is revoked.
    event PendingRootRevoked();

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event RewardsClaimed(address indexed account, address indexed reward, uint256 amount);

    /// @notice Emitted when the ownership of a merkle tree distribution is transferred.
    /// @param previousOwner The previous owner of the merkle tree distribution.
    /// @param newOwner The new owner of the merkle tree distribution.
    event DistributionOwnerSet(address indexed previousOwner, address indexed newOwner);
}
