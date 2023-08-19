// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

type Id is bytes32;

/// @title IUniversalRewardsDistributor
/// @author Morpho Labs
/// @notice UniversalRewardsDistributor's interface.
interface IUniversalRewardsDistributor {

    /// @notice The pending root struct for a merkle tree distribution during the timelock.
    struct PendingRoot {
        /// @dev The block timestamp of the pending root submission.
        uint256 submittedAt;
        /// @dev The submitted pending root.
        bytes32 root;
    }

    /* EVENTS */

    /// @notice Emitted when the merkle tree's root is updated.
    /// @param treeId The id of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    event RootUpdated(Id indexed treeId, bytes32 newRoot);

    /// @notice Emitted when a new merkle tree's root is submitted.
    /// @param newRoot The new merkle tree's root.
    event RootSubmitted(Id indexed treeId, bytes32 newRoot);


    /// @notice Emitted when a new Treasury.
    /// @param treeId The id of the merkle tree distribution.
    /// @param newTreasury The new merkle tree's treasury where rewards are pulled from.
    event TreasuryUpdated(Id indexed treeId, address newTreasury);

    /// @notice Emitted when a new merkle tree's treasury is suggested by the owner.
    /// @param treeId The id of the merkle tree distribution.
    /// @param newTreasury The new treasury that needs to approve the change.
    event TreasurySuggested(Id indexed treeId, address newTreasury);


    /// @notice Emitted when a merkle tree is frozen or unfrozen by the owner.
    /// @param treeId The id of the merkle tree distribution.
    /// @param frozen The new merkle tree's frozen state.
    event Frozen(Id indexed treeId, bool frozen);

    /// @notice Emitted when a merkle tree distribution timelock is modified.
    /// @param treeId The id of the merkle tree distribution.
    /// @param timelock The new merkle tree's timelock.
    event TimelockUpdated(Id indexed treeId, uint256 timelock);

    /// @notice Emitted when a merkle tree distribution is created.
    /// @param treeId The id of the merkle tree distribution.
    /// @param owner The owner of the merkle tree distribution.
    /// @param initialTimelock The initial timelock of the merkle tree distribution.
    event DistributionCreated(Id indexed treeId, address indexed owner, uint256 initialTimelock);

    /// @notice Emitted when a merkle tree updater is added or removed.
    /// @param treeId The id of the merkle tree distribution.
    /// @param rootUpdater The merkle tree updater.
    /// @param active The merkle tree updater's active state.
    event RootUpdaterUpdated(Id indexed treeId, address indexed rootUpdater, bool active);

    /// @notice Emitted when a merkle tree's pending root is revoked.
    /// @param treeId The id of the merkle tree distribution.
    event PendingRootRevoked(Id indexed treeId);

    /// @notice Emitted when rewards are claimed.
    /// @param treeId The id of the merkle tree distribution.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event RewardsClaimed(Id indexed treeId, address indexed account, address indexed reward, uint256 amount);


    /// @notice Emitted when the ownership of a merkle tree distribution is transferred.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param previousOwner The previous owner of the merkle tree distribution.
    /// @param newOwner The new owner of the merkle tree distribution.
    event DistributionOwnershipTransferred(Id indexed distributionId, address indexed previousOwner, address indexed newOwner);
    /* EXTERNAL */

    function proposeRoot(Id id, bytes32 newRoot) external;
    function confirmRootUpdate(Id id) external;
    function claim(Id id, address account, address reward, uint256 claimable, bytes32[] calldata proof)
    external;
    function createDistribution(uint256 initialTimelock, bytes32 initialRoot) external;
    function suggestTreasury(Id id, address newTreasury) external;
    function acceptAsTreasury(Id id) external;
    function freeze(Id id, bool isFrozen) external;
    function forceUpdateRoot(Id id, bytes32 newRoot) external;
    function updateTimelock(Id id, uint256 newTimelock) external;
    function editRootUpdater(Id id, address updater, bool active) external;
    function revokePendingRoot(Id id) external;
}
