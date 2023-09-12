// SPDX-License-Identifier: MIT
pragma solidity >=0.7.4;

/// @notice The pending root struct for a merkle tree distribution during the timelock.
struct PendingRoot {
    /// @dev The block timestamp of the pending root submission.
    uint256 submittedAt;
    /// @dev The submitted pending root.
    bytes32 root;
    /// @dev The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    bytes32 ipfsHash;
}

/// @title IUniversalRewardsDistributor
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice UniversalRewardsDistributor's interface.
interface IUniversalRewardsDistributor {
    /* EVENTS */

    /// @notice Emitted when the merkle tree's root is updated.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootUpdated(bytes32 newRoot, bytes32 newIpfsHash);

    /// @notice Emitted when a new merkle tree's root is submitted.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    event RootProposed(bytes32 newRoot, bytes32 newIpfsHash);


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
    event RewardsClaimed(address indexed account, address indexed reward, uint256 amount
    );

    /// @notice Emitted when the ownership of a merkle tree distribution is transferred.
    /// @param previousOwner The previous owner of the merkle tree distribution.
    /// @param newOwner The new owner of the merkle tree distribution.
    event DistributionOwnerSet(address indexed previousOwner, address indexed newOwner);

    /* EXTERNAL */

    function root() external view returns (bytes32);
    function owner() external view returns (address);
    function timelock() external view returns (uint256);
    function ipfsHash() external view returns (bytes32);
    function isUpdater(address) external view returns (bool);
    function pendingRoot() external view returns (uint256 submittedAt, bytes32 root, bytes32 ipfsHash);
    function claimed(address, address) external view returns (uint256);

    function acceptRootUpdate() external;
    function forceUpdateRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
    function updateTimelock(uint256 newTimelock) external;
    function updateRootUpdater(address updater, bool active) external;
    function revokePendingRoot() external;
    function setDistributionOwner(address newOwner) external;

    function proposeRoot( bytes32 newRoot, bytes32 ipfsHash) external;

    function claim(address account, address reward, uint256 claimable, bytes32[] memory proof)
        external;
}

interface IPendingRoot {
    function pendingRoot() external view returns (PendingRoot memory);
}
