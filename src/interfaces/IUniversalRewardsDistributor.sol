// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

type Id is bytes32;

/// @title IUniversalRewardsDistributor
/// @author MerlinEgalite
/// @notice UniversalRewardsDistributor's interface.
interface IUniversalRewardsDistributor {

    struct PendingRoot {
        uint256 submittedAt;
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


    event TreasuryUpdated(Id indexed treeId, address newTreasury);
    event TreasurySuggested(Id indexed treeId, address newTreasury);

    event Frozen(Id indexed treeId, bool frozen);

    event TimelockUpdated(Id indexed treeId, uint256 timelock);

    event DistributionCreated(Id indexed treeId, address indexed owner, uint256 initialTimelock);

    event RootUpdaterUpdated(Id indexed treeId, address indexed rootUpdater, bool active);

    event PendingRootRevoked(Id indexed treeId);

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event RewardsClaimed(Id indexed treeId, address indexed account, address indexed reward, uint256 amount);

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
