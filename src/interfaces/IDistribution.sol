// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title IDistribution
/// @author Morpho Labs
/// @notice Distribution's interface.
interface IDistribution {
    /// @notice The pending root struct for a merkle tree distribution during the timelock.
    struct PendingRoot {
        /// @dev The block timestamp of the pending root submission.
        uint256 submittedAt;
        /// @dev The submitted pending root.
        bytes32 root;
        // @dev The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
        bytes32 ipfsHash;
    }

    /* EVENTS */

    /// @notice Emitted when the merkle tree's root is updated.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootUpdated(bytes32 newRoot, bytes32 newIpfsHash);

    /// @notice Emitted when a new merkle tree's root is submitted.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootProposed(bytes32 newRoot, bytes32 newIpfsHash);

    /// @notice Emitted when a merkle tree is frozen or unfrozen by the owner.
    /// @param frozen The new merkle tree's frozen state.
    event Frozen(bool frozen);

    /// @notice Emitted when a merkle tree distribution timelock is modified.
    /// @param timelock The new merkle tree's timelock.
    event TimelockUpdated(uint256 timelock);

    /// @notice Emitted when a merkle tree distribution is created.
    /// @param owner The owner of the merkle tree distribution.
    /// @param initialTimelock The initial timelock of the merkle tree distribution.
    event DistributionCreated(address indexed caller, address indexed owner, uint256 initialTimelock);

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

    /* EXTERNAL */

    function proposeRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
    function acceptRootUpdate() external;
    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof) external;
    function forceUpdateRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
    function updateTimelock(uint256 newTimelock) external;
    function updateRootUpdater(address updater, bool active) external;
    function revokePendingRoot() external;
    function setOwner(address newOwner) external;
}
