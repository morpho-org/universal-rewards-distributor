// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniversalRewardsDistributor, Id} from "./interfaces/IUniversalRewardsDistributor.sol";

import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @title UniversalRewardsDistributor
/// @author Morpho Labs
/// @notice This contract enables the distribution of various reward tokens to multiple accounts using different permissionLess Merkle trees.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor {
    using SafeTransferLib for ERC20;

    /// @notice The merkle tree's roots of a given distribution.
    mapping(Id => bytes32) public roots;

    /// @notice The `amount` of `reward` token already claimed by `account` for one given distribution.
    mapping(Id => mapping(address account => mapping(address reward => uint256 amount))) public claimed;

    /// @notice The treasury address of a given distribution.
    /// @dev The treasury is the address from which the rewards are sent by using a classic approval.
    mapping(Id => address) public treasuries;

    /// @notice The address that can update the distributions parameters, and freeze a root.
    mapping(Id => address) public rootOwner;

    /// @notice The addresses that can update the merkle tree's root for a given distribution.
    mapping(Id => mapping(address => bool)) public rootUpdaters;

    /// @notice The timelock for a given distribution.
    mapping(Id => uint256) public timelocks;

    /// @notice The pending root for a given distribution.
    /// @dev If the pending root is set, the root can be updated after the timelock has expired.
    /// @dev The pending root is skipped if the timelock is set to 0.
    mapping(Id => PendingRoot) public pendingRoots;

    /// @notice The pending treasury for a given distribution.
    /// @dev The pending treasury has to accept the treasury role to become the new treasury.
    mapping(Id => address) public pendingTreasuries;

    /// @notice The frozen status of a given distribution.
    /// @dev A frozen distribution cannot be claimed by users.
    mapping(Id => bool) public frozen;

    modifier onlyUpdater(Id distributionId) {
        require(
            rootUpdaters[distributionId][msg.sender] || msg.sender == rootOwner[distributionId],
            "UniversalRewardsDistributor: caller is not the updater"
        );
        _;
    }

    modifier onlyTreasury(Id distributionId) {
        require(msg.sender == treasuries[distributionId], "UniversalRewardsDistributor: caller is not the treasury");
        _;
    }

    modifier onlyOwner(Id distributionId) {
        require(msg.sender == rootOwner[distributionId], "UniversalRewardsDistributor: caller is not the owner");
        _;
    }

    modifier notFrozen(Id distributionId) {
        require(!frozen[distributionId], "UniversalRewardsDistributor: frozen");
        _;
    }

    /* EXTERNAL */

    /// @notice Updates the current merkle tree's root.
    /// @param newRoot The new merkle tree's root.
    function proposeRoot(Id distributionId, bytes32 newRoot) external onlyUpdater(distributionId) {
        if (timelocks[distributionId] == 0) {
            roots[distributionId] = newRoot;
            delete pendingRoots[distributionId];
            emit RootUpdated(distributionId, newRoot);
        } else {
            pendingRoots[distributionId] = PendingRoot(block.timestamp, newRoot);
            emit RootSubmitted(distributionId, newRoot);
        }
    }

    /// @notice Updates the current merkle tree's root.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function confirmRootUpdate(Id distributionId) external {
        require(pendingRoots[distributionId].submittedAt > 0, "UniversalRewardsDistributor: no pending root");
        require(
            block.timestamp >= pendingRoots[distributionId].submittedAt + timelocks[distributionId],
            "UniversalRewardsDistributor: timelock not expired"
        );
        roots[distributionId] = pendingRoots[distributionId].root;
        delete pendingRoots[distributionId];
        emit RootUpdated(distributionId, pendingRoots[distributionId].root);
    }

    /// @notice Claims rewards.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that valdistributionIdates this claim.
    function claim(Id distributionId, address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
        notFrozen(distributionId)
    {
        require(roots[distributionId] != bytes32(0), "UniversalRewardsDistributor: root is not set");

        require(
            MerkleProof.verifyCalldata(
                proof, roots[distributionId], keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
            ),
            "UniversalRewardsDistributor: invalid proof or expired"
        );

        uint256 amount = claimable - claimed[distributionId][account][reward];

        require(amount > 0, "UniversalRewardsDistributor: already claimed");

        claimed[distributionId][account][reward] = claimable;

        ERC20(reward).safeTransferFrom(treasuries[distributionId], account, amount);
        emit RewardsClaimed(distributionId, account, reward, amount);
    }

    /// @notice Creates a new distribution.
    /// @param initialTimelock The initial timelock for the new distribution.
    /// @param initialRoot The initial merkle tree's root for the new distribution.
    /// @dev The caller of this function is the owner and the treasury of the new distribution.
    function createDistribution(uint256 initialTimelock, bytes32 initialRoot) external returns (Id distributionId) {
        distributionId = Id.wrap(keccak256(abi.encode(msg.sender, block.timestamp)));

        require(rootOwner[distributionId] == address(0), "UniversalRewardsDistributor: distributionId already exists");

        rootOwner[distributionId] = msg.sender;
        treasuries[distributionId] = msg.sender;
        timelocks[distributionId] = initialTimelock;

        emit DistributionCreated(distributionId, msg.sender, initialTimelock);
        if (initialRoot != bytes32(0)) {
            roots[distributionId] = initialRoot;
            emit RootUpdated(distributionId, initialRoot);
        }
    }

    /// @notice Submits a new treasury address for a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newTreasury The new treasury address.
    function suggestTreasury(Id distributionId, address newTreasury) external onlyOwner(distributionId) {
        pendingTreasuries[distributionId] = newTreasury;
        emit TreasurySuggested(distributionId, newTreasury);
    }

    /// @notice Accepts the treasury role for a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    function acceptAsTreasury(Id distributionId) external {
        require(msg.sender == pendingTreasuries[distributionId], "UniversalRewardsDistributor: caller is not the pending treasury");
        treasuries[distributionId] = pendingTreasuries[distributionId];
        delete pendingTreasuries[distributionId];
        emit TreasuryUpdated(distributionId, treasuries[distributionId]);
    }

    /// @notice Freeze a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param isFrozen Whether the distribution should be frozen or not.
    function freeze(Id distributionId, bool isFrozen) external onlyOwner(distributionId) {
        frozen[distributionId] = isFrozen;
        emit Frozen(distributionId, isFrozen);
    }

    /// @notice Force update the root of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev The distribution must be frozen before.
    function forceUpdateRoot(Id distributionId, bytes32 newRoot) external onlyOwner(distributionId) {
        require(frozen[distributionId], "UniversalRewardsDistributor: not frozen");
        roots[distributionId] = newRoot;
        emit RootUpdated(distributionId, newRoot);
    }

    /// @notice Update the timelock of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function updateTimelock(Id distributionId, uint256 newTimelock) external onlyOwner(distributionId) {
        if(newTimelock < timelocks[distributionId]) {
            require(
                pendingRoots[distributionId].submittedAt == 0 || pendingRoots[distributionId].submittedAt + timelocks[distributionId] <= block.timestamp,
                "UniversalRewardsDistributor: timelock not expired"
            );
        }
        timelocks[distributionId] = newTimelock;
        emit TimelockUpdated(distributionId, newTimelock);
    }

    /// @notice Update the root updater of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function editRootUpdater(Id distributionId, address updater, bool active) external onlyOwner(distributionId) {
        rootUpdaters[distributionId][updater] = active;
        emit RootUpdaterUpdated(distributionId, updater, active);
    }

    /// @notice Revoke the pending root of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @dev This function can only be called by the owner of the distribution at any time.
    function revokePendingRoot(Id distributionId) external onlyOwner(distributionId) {
        require(pendingRoots[distributionId].submittedAt != 0, "UniversalRewardsDistributor: no pending root");
        delete pendingRoots[distributionId];
        emit PendingRootRevoked(distributionId);
    }

    function transferDistributionOwnership(Id distributionId, address newOwner) external onlyOwner(distributionId) {
        rootOwner[distributionId] = newOwner;
        emit DistributionOwnershipTransferred(distributionId, msg.sender,  newOwner);
    }


    function getPendingRoot(Id distributionId) external view returns (PendingRoot memory) {
        return pendingRoots[distributionId];
    }
}
