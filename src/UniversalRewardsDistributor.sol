// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniversalRewardsDistributor} from "./interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";

/// @title UniversalRewardsDistributor
/// @author Morpho Labs
/// @notice This contract enables the distribution of various reward tokens to multiple accounts using different permissionless Merkle trees.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor {
    using SafeTransferLib for ERC20;

    uint256 public nextDistributionId = 1;

    /// @notice The merkle tree's roots of a given distribution.
    mapping(uint256 => bytes32) public rootOf;

    /// @notice The `amount` of `reward` token already claimed by `account` for one given distribution.
    mapping(uint256 => mapping(address account => mapping(address reward => uint256 amount))) public claimed;

    /// @notice The treasury address of a given distribution.
    /// @dev The treasury is the address from which the rewards are sent by using a classic approval.
    mapping(uint256 => address) public treasuryOf;

    /// @notice The address that can update the distribution parameters, and freeze a root.
    mapping(uint256 => address) public ownerOf;

    /// @notice The addresses that can update the merkle tree's root for a given distribution.
    mapping(uint256 => mapping(address => bool)) public isUpdaterOf;

    /// @notice The timelock for a given distribution.
    mapping(uint256 => uint256) public timelockOf;

    /// @notice The pending root for a given distribution.
    /// @dev If the pending root is set, the root can be updated after the timelock has expired.
    /// @dev The pending root is skipped if the timelock is set to 0.
    mapping(uint256 => PendingRoot) public pendingRootOf;

    /// @notice The pending treasury for a given distribution.
    /// @dev The pending treasury has to accept the treasury role to become the new treasury.
    mapping(uint256 => address) public pendingTreasuryOf;

    /// @notice The frozen status of a given distribution.
    /// @dev A frozen distribution cannot be claimed by users.
    mapping(uint256 => bool) public isFrozen;

    modifier onlyUpdater(uint256 distributionId) {
        require(
            isUpdaterOf[distributionId][msg.sender] || msg.sender == ownerOf[distributionId],
            ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER
        );
        _;
    }

    modifier onlyTreasury(uint256 distributionId) {
        require(msg.sender == treasuryOf[distributionId], ErrorsLib.CALLER_NOT_TREASURY);
        _;
    }

    modifier onlyOwner(uint256 distributionId) {
        require(msg.sender == ownerOf[distributionId], ErrorsLib.CALLER_NOT_OWNER);
        _;
    }

    modifier notFrozen(uint256 distributionId) {
        require(!isFrozen[distributionId], ErrorsLib.FROZEN);
        _;
    }

    /* EXTERNAL */

    /// @notice Proposes a new merkle tree root.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    function proposeRoot(uint256 distributionId, bytes32 newRoot)
        external
        onlyUpdater(distributionId)
        notFrozen(distributionId)
    {
        if (timelockOf[distributionId] == 0) {
            rootOf[distributionId] = newRoot;
            delete pendingRootOf[distributionId];
            emit RootUpdated(distributionId, newRoot);
        } else {
            pendingRootOf[distributionId] = PendingRoot(block.timestamp, newRoot);
            emit RootProposed(distributionId, newRoot);
        }
    }

    /// @notice Accepts the current pending merkle tree's root.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function acceptRootUpdate(uint256 distributionId) external notFrozen(distributionId) {
        PendingRoot memory pendingRoot = pendingRootOf[distributionId];
        require(pendingRoot.submittedAt > 0, ErrorsLib.NO_PENDING_ROOT);
        require(block.timestamp >= pendingRoot.submittedAt + timelockOf[distributionId], ErrorsLib.TIMELOCK_NOT_EXPIRED);

        rootOf[distributionId] = pendingRoot.root;
        delete pendingRootOf[distributionId];

        emit RootUpdated(distributionId, pendingRoot.root);
    }

    /// @notice Claims rewards.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(uint256 distributionId, address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
        notFrozen(distributionId)
    {
        require(rootOf[distributionId] != bytes32(0), ErrorsLib.ROOT_NOT_SET);
        require(
            MerkleProof.verifyCalldata(
                proof,
                rootOf[distributionId],
                keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
            ),
            ErrorsLib.INVALID_PROOF_OR_EXPIRED
        );

        uint256 amount = claimable - claimed[distributionId][account][reward];

        require(amount > 0, ErrorsLib.ALREADY_CLAIMED);

        claimed[distributionId][account][reward] = claimable;

        ERC20(reward).safeTransferFrom(treasuryOf[distributionId], account, amount);

        emit RewardsClaimed(distributionId, account, reward, amount);
    }

    /// @notice Creates a new distribution.
    /// @param initialTimelock The initial timelock for the new distribution.
    /// @param initialRoot The initial merkle tree's root for the new distribution.
    /// @dev The caller of this function is the owner and the treasury of the new distribution.
    function createDistribution(uint256 initialTimelock, bytes32 initialRoot)
        external
        returns (uint256 distributionId)
    {
        distributionId = nextDistributionId++;
        ownerOf[distributionId] = msg.sender;
        treasuryOf[distributionId] = msg.sender;
        timelockOf[distributionId] = initialTimelock;

        emit DistributionCreated(distributionId, msg.sender, initialTimelock);

        if (initialRoot != bytes32(0)) {
            rootOf[distributionId] = initialRoot;
            emit RootUpdated(distributionId, initialRoot);
        }
    }

    /// @notice Proposes a new treasury address for a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newTreasury The new treasury address.
    function proposeTreasury(uint256 distributionId, address newTreasury) external onlyOwner(distributionId) {
        pendingTreasuryOf[distributionId] = newTreasury;
        emit TreasuryProposed(distributionId, newTreasury);
    }

    /// @notice Accepts the treasury role for a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    function acceptAsTreasury(uint256 distributionId) external {
        require(msg.sender == pendingTreasuryOf[distributionId], ErrorsLib.CALLER_NOT_PENDING_TREASURY);

        treasuryOf[distributionId] = msg.sender;
        delete pendingTreasuryOf[distributionId];

        emit TreasuryUpdated(distributionId, msg.sender);
    }

    /// @notice Freezes a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newIsFrozen Whether the distribution should be frozen or not.
    function freeze(uint256 distributionId, bool newIsFrozen) external onlyOwner(distributionId) {
        isFrozen[distributionId] = newIsFrozen;
        emit Frozen(distributionId, newIsFrozen);
    }

    /// @notice Forces update the root of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev The distribution must be frozen before.
    function forceUpdateRoot(uint256 distributionId, bytes32 newRoot) external onlyOwner(distributionId) {
        require(isFrozen[distributionId], ErrorsLib.NOT_FROZEN);
        rootOf[distributionId] = newRoot;
        emit RootUpdated(distributionId, newRoot);
    }

    /// @notice Updates the timelock of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function updateTimelock(uint256 distributionId, uint256 newTimelock) external onlyOwner(distributionId) {
        if (newTimelock < timelockOf[distributionId]) {
            PendingRoot memory pendingRoot = pendingRootOf[distributionId];
            require(
                pendingRoot.submittedAt == 0 || pendingRoot.submittedAt + timelockOf[distributionId] <= block.timestamp,
                ErrorsLib.TIMELOCK_NOT_EXPIRED
            );
        }

        timelockOf[distributionId] = newTimelock;
        emit TimelockUpdated(distributionId, newTimelock);
    }

    /// @notice Updates the root updater of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function updateRootUpdater(uint256 distributionId, address updater, bool active)
        external
        onlyOwner(distributionId)
    {
        isUpdaterOf[distributionId][updater] = active;
        emit RootUpdaterUpdated(distributionId, updater, active);
    }

    /// @notice Revokes the pending root of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @dev This function can only be called by the owner of the distribution at any time.
    function revokePendingRoot(uint256 distributionId) external onlyOwner(distributionId) {
        require(pendingRootOf[distributionId].submittedAt != 0, ErrorsLib.NO_PENDING_ROOT);

        delete pendingRootOf[distributionId];
        emit PendingRootRevoked(distributionId);
    }

    function transferDistributionOwnership(uint256 distributionId, address newOwner)
        external
        onlyOwner(distributionId)
    {
        ownerOf[distributionId] = newOwner;
        emit DistributionOwnershipTransferred(distributionId, msg.sender, newOwner);
    }

    function getPendingRoot(uint256 distributionId) external view returns (PendingRoot memory) {
        return pendingRootOf[distributionId];
    }
}
