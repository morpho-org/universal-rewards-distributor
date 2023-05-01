// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title IUniversalRewardsDistributor
/// @author MerlinEgalite
/// @notice UniversalRewardsDistributor's interface.
interface IUniversalRewardsDistributor {
    /* EVENTS */

    /// @notice Emitted when the merkle tree's root is updated.
    /// @param newRoot The new merkle tree's root.
    event RootUpdated(bytes32 newRoot);

    /// @notice Emitted when rewards are claimed.
    /// @param account The address for which rewards are claimd rewards for.
    /// @param reward The address of the reward token.
    /// @param amount The amount of reward token claimed.
    event RewardsClaimed(address account, address reward, uint256 amount);

    /* ERRORS */

    /// @notice Thrown when the merkle proof is invalid or expired.
    error ProofInvalidOrExpired();

    /// @notice Thrown when the rewards have already been claimed.
    error AlreadyClaimed();

    /* EXTERNAL */

    function updateRoot(bytes32 newRoot) external;

    function skim(address token) external;

    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof) external;
}
