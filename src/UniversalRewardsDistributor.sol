// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniversalRewardsDistributor} from "./interfaces/IUniversalRewardsDistributor.sol";

import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @title UniversalRewardsDistributor
/// @author Morpho Labs
/// @notice This contract enables the distribution of various reward tokens to multiple accounts using different permissionless Merkle trees.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor {
    using SafeTransferLib for ERC20;

    uint256 public nextId = 1;

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

    modifier onlyUpdater(uint256 id) {
        require(
            isUpdaterOf[id][msg.sender] || msg.sender == ownerOf[id],
            "UniversalRewardsDistributor: caller is not the updater"
        );
        _;
    }

    modifier onlyTreasury(uint256 id) {
        require(msg.sender == treasuryOf[id], "UniversalRewardsDistributor: caller is not the treasury");
        _;
    }

    modifier onlyOwner(uint256 id) {
        require(msg.sender == ownerOf[id], "UniversalRewardsDistributor: caller is not the owner");
        _;
    }

    modifier notFrozen(uint256 id) {
        require(!isFrozen[id], "UniversalRewardsDistributor: frozen");
        _;
    }

    /* EXTERNAL */

    /// @notice Proposes a new merkle tree root.
    /// @param id The id of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    function proposeRoot(uint256 id, bytes32 newRoot) external onlyUpdater(id) notFrozen(id) {
        if (timelockOf[id] == 0) {
            rootOf[id] = newRoot;
            delete pendingRootOf[id];
            emit RootUpdated(id, newRoot);
        } else {
            pendingRootOf[id] = PendingRoot(block.timestamp, newRoot);
            emit RootProposed(id, newRoot);
        }
    }

    /// @notice Accepts the current pending merkle tree's root.
    /// @param id The id of the merkle tree distribution.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function acceptRootUpdate(uint256 id) external notFrozen(id) {
        PendingRoot memory pendingRoot = pendingRootOf[id];
        require(pendingRoot.submittedAt > 0, "UniversalRewardsDistributor: no pending root");
        require(
            block.timestamp >= pendingRoot.submittedAt + timelockOf[id],
            "UniversalRewardsDistributor: timelock not expired"
        );

        rootOf[id] = pendingRoot.root;
        delete pendingRootOf[id];

        emit RootUpdated(id, pendingRoot.root);
    }

    /// @notice Claims rewards.
    /// @param id The id of the merkle tree distribution.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(uint256 id, address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
        notFrozen(id)
    {
        require(rootOf[id] != bytes32(0), "UniversalRewardsDistributor: root is not set");
        require(
            MerkleProof.verifyCalldata(
                proof, rootOf[id], keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
            ),
            "UniversalRewardsDistributor: invalid proof or expired"
        );

        uint256 amount = claimable - claimed[id][account][reward];

        require(amount > 0, "UniversalRewardsDistributor: already claimed");

        claimed[id][account][reward] = claimable;

        ERC20(reward).safeTransferFrom(treasuryOf[id], account, amount);

        emit RewardsClaimed(id, account, reward, amount);
    }

    /// @notice Creates a new distribution.
    /// @param initialTimelock The initial timelock for the new distribution.
    /// @param initialRoot The initial merkle tree's root for the new distribution.
    /// @dev The caller of this function is the owner and the treasury of the new distribution.
    function createDistribution(uint256 initialTimelock, bytes32 initialRoot) external returns (uint256 id) {
        id = nextId++;
        ownerOf[id] = msg.sender;
        treasuryOf[id] = msg.sender;
        timelockOf[id] = initialTimelock;

        emit DistributionCreated(id, msg.sender, initialTimelock);

        if (initialRoot != bytes32(0)) {
            rootOf[id] = initialRoot;
            emit RootUpdated(id, initialRoot);
        }
    }

    /// @notice Proposes a new treasury address for a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newTreasury The new treasury address.
    function proposeTreasury(uint256 id, address newTreasury) external onlyOwner(id) {
        pendingTreasuryOf[id] = newTreasury;
        emit TreasuryProposed(id, newTreasury);
    }

    /// @notice Accepts the treasury role for a given distribution.
    /// @param id The id of the merkle tree distribution.
    function acceptAsTreasury(uint256 id) external {
        require(msg.sender == pendingTreasuryOf[id], "UniversalRewardsDistributor: caller is not the pending treasury");

        treasuryOf[id] = msg.sender;
        delete pendingTreasuryOf[id];

        emit TreasuryUpdated(id, msg.sender);
    }

    /// @notice Freezes a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newIsFrozen Whether the distribution should be frozen or not.
    function freeze(uint256 id, bool newIsFrozen) external onlyOwner(id) {
        isFrozen[id] = newIsFrozen;
        emit Frozen(id, newIsFrozen);
    }

    /// @notice Forces update the root of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev The distribution must be frozen before.
    function forceUpdateRoot(uint256 id, bytes32 newRoot) external onlyOwner(id) {
        require(isFrozen[id], "UniversalRewardsDistributor: not frozen");
        rootOf[id] = newRoot;
        emit RootUpdated(id, newRoot);
    }

    /// @notice Updates the timelock of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function updateTimelock(uint256 id, uint256 newTimelock) external onlyOwner(id) {
        if (newTimelock < timelockOf[id]) {
            PendingRoot memory pendingRoot = pendingRootOf[id];
            require(
                pendingRoot.submittedAt == 0 || pendingRoot.submittedAt + timelockOf[id] <= block.timestamp,
                "UniversalRewardsDistributor: timelock not expired"
            );
        }

        timelockOf[id] = newTimelock;
        emit TimelockUpdated(id, newTimelock);
    }

    /// @notice Updates the root updater of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function updateRootUpdater(uint256 id, address updater, bool active) external onlyOwner(id) {
        isUpdaterOf[id][updater] = active;
        emit RootUpdaterUpdated(id, updater, active);
    }

    /// @notice Revokes the pending root of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @dev This function can only be called by the owner of the distribution at any time.
    function revokePendingRoot(uint256 id) external onlyOwner(id) {
        require(pendingRootOf[id].submittedAt != 0, "UniversalRewardsDistributor: no pending root");

        delete pendingRootOf[id];
        emit PendingRootRevoked(id);
    }

    function transferDistributionOwnership(uint256 id, address newOwner) external onlyOwner(id) {
        ownerOf[id] = newOwner;
        emit DistributionOwnershipTransferred(id, msg.sender, newOwner);
    }

    function getPendingRoot(uint256 id) external view returns (PendingRoot memory) {
        return pendingRootOf[id];
    }
}
