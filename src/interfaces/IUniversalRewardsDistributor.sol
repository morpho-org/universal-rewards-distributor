// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

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
    /// @param distributionId The id of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    event RootUpdated(uint256 indexed distributionId, bytes32 newRoot);

    /// @notice Emitted when a new merkle tree's root is submitted.
    /// @param newRoot The new merkle tree's root.
    event RootSubmitted(uint256 indexed distributionId, bytes32 newRoot);

    /// @notice Emitted when a new Treasury.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param newTreasury The new merkle tree's treasury where rewards are pulled from.
    event TreasuryUpdated(uint256 indexed distributionId, address newTreasury);

    /// @notice Emitted when a new merkle tree's treasury is suggested by the owner.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param newTreasury The new treasury that needs to approve the change.
    event TreasurySuggested(uint256 indexed distributionId, address newTreasury);

    /// @notice Emitted when a merkle tree is frozen or unfrozen by the owner.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param frozen The new merkle tree's frozen state.
    event Frozen(uint256 indexed distributionId, bool frozen);

    /// @notice Emitted when a merkle tree distribution timelock is modified.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param timelock The new merkle tree's timelock.
    event TimelockUpdated(uint256 indexed distributionId, uint256 timelock);

    /// @notice Emitted when a merkle tree distribution is created.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param owner The owner of the merkle tree distribution.
    /// @param initialTimelock The initial timelock of the merkle tree distribution.
    event DistributionCreated(uint256 indexed distributionId, address indexed owner, uint256 initialTimelock);

    /// @notice Emitted when a merkle tree updater is added or removed.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param rootUpdater The merkle tree updater.
    /// @param active The merkle tree updater's active state.
    event RootUpdaterUpdated(uint256 indexed distributionId, address indexed rootUpdater, bool active);

    /// @notice Emitted when a merkle tree's pending root is revoked.
    /// @param distributionId The id of the merkle tree distribution.
    event PendingRootRevoked(uint256 indexed distributionId);

    /// @notice Emitted when rewards are claimed.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event RewardsClaimed(uint256 indexed distributionId, address indexed account, address indexed reward, uint256 amount);

    /// @notice Emitted when the ownership of a merkle tree distribution is transferred.
    /// @param distributionId The id of the merkle tree distribution.
    /// @param previousOwner The previous owner of the merkle tree distribution.
    /// @param newOwner The new owner of the merkle tree distribution.
    event DistributionOwnershipTransferred(
        uint256 indexed distributionId, address indexed previousOwner, address indexed newOwner
    );

    /* EXTERNAL */

    function proposeRoot(uint256 id, bytes32 newRoot) external;
    function confirmRootUpdate(uint256 id) external;
    function claim(uint256 id, address account, address reward, uint256 claimable, bytes32[] calldata proof) external;
    function createDistribution(uint256 initialTimelock, bytes32 initialRoot) external returns (uint256 distributionId);
    function suggestTreasury(uint256 id, address newTreasury) external;
    function acceptAsTreasury(uint256 id) external;
    function freeze(uint256 id, bool isFrozen) external;
    function forceUpdateRoot(uint256 id, bytes32 newRoot) external;
    function updateTimelock(uint256 id, uint256 newTimelock) external;
    function updateRootUpdater(uint256 id, address updater, bool active) external;
    function revokePendingRoot(uint256 id) external;
    function getPendingRoot(uint256 id) external view returns (PendingRoot memory);
}
