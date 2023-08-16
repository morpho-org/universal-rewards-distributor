// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniversalRewardsDistributor, Id} from "./interfaces/IUniversalRewardsDistributor.sol";

import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

/// @title UniversalRewardsDistributor
/// @author MerlinEgalite
/// @notice This contract allows to distribute different rewards tokens to multiple accounts using a Merkle tree.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor {
    using SafeTransferLib for ERC20;

    /* STORAGE */
    address public immutable IS_PERMISSIONED;

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

    modifier onlyUpdater(Id id) {
        require(
            rootUpdaters[id][msg.sender] || msg.sender == rootOwner[id],
            "UniversalRewardsDistributor: caller is not the updater"
        );
        _;
    }

    modifier onlyTreasury(Id id) {
        require(msg.sender == treasuries[id], "UniversalRewardsDistributor: caller is not the treasury");
        _;
    }

    modifier onlyOwner(Id id) {
        require(msg.sender == rootOwner[id], "UniversalRewardsDistributor: caller is not the owner");
        _;
    }

    modifier notFrozen(Id id) {
        require(!frozen[id], "UniversalRewardsDistributor: frozen");
        _;
    }

    modifier isCreationAllowed() {
        require(
            IS_PERMISSIONED == address(0) || msg.sender == IS_PERMISSIONED,
            "UniversalRewardsDistributor: creation not allowed"
        );
        _;
    }

    /// @notice The constructor of the contract.
    /// @param isPermissionLess Whether the contract is permissionLess or not.
    constructor(bool isPermissionLess) {
        if (!isPermissionLess) {
            IS_PERMISSIONED = msg.sender;
        }
    }
    /* EXTERNAL */

    /// @notice Updates the current merkle tree's root.
    /// @param newRoot The new merkle tree's root.
    function proposeRoot(Id id, bytes32 newRoot) external onlyUpdater(id) {
        if (timelocks[id] == 0) {
            roots[id] = newRoot;
            delete pendingRoots[id];
            emit RootUpdated(id, newRoot);
        }
        pendingRoots[id] = PendingRoot(block.timestamp, newRoot);
        emit RootSubmitted(id, newRoot);
    }

    /// @notice Updates the current merkle tree's root.
    /// @param id The id of the merkle tree distribution.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function confirmRootUpdate(Id id) external {
        require(pendingRoots[id].submittedAt > 0, "UniversalRewardsDistributor: no pending root");
        require(
            block.timestamp >= pendingRoots[id].submittedAt + timelocks[id],
            "UniversalRewardsDistributor: timelock not expired"
        );
        roots[id] = pendingRoots[id].root;
        delete pendingRoots[id];
        emit RootUpdated(id, pendingRoots[id].root);
    }

    /// @notice Claims rewards.
    /// @param id The id of the merkle tree distribution.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(Id id, address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
        notFrozen(id)
    {
        require(roots[id] != bytes32(0), "UniversalRewardsDistributor: root is not set");

        require(
            MerkleProof.verifyCalldata(
                proof, roots[id], keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
            ),
            "UniversalRewardsDistributor: invalid proof or expired"
        );

        uint256 amount = claimable - claimed[id][account][reward];

        require(amount > 0, "UniversalRewardsDistributor: already claimed");

        claimed[id][account][reward] = claimable;

        ERC20(reward).safeTransferFrom(treasuries[id], account, amount);
        emit RewardsClaimed(id, account, reward, amount);
    }

    /// @notice Creates a new distribution.
    /// @param initialTimelock The initial timelock for the new distribution.
    /// @param initialRoot The initial merkle tree's root for the new distribution.
    /// @dev The caller of this function is the owner and the treasury of the new distribution.
    function createDistribution(uint256 initialTimelock, bytes32 initialRoot) external isCreationAllowed {
        Id id = Id.wrap(keccak256(abi.encode(msg.sender, block.timestamp)));
        rootOwner[id] = msg.sender;
        treasuries[id] = msg.sender;
        timelocks[id] = initialTimelock;
        roots[id] = initialRoot;

        emit DistributionCreated(id, msg.sender, initialTimelock);
        if (initialRoot != bytes32(0)) {
            emit RootUpdated(id, initialRoot);
        }
    }

    /// @notice Submits a new treasury address for a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newTreasury The new treasury address.
    function suggestTreasury(Id id, address newTreasury) external onlyOwner(id) {
        pendingTreasuries[id] = newTreasury;
        emit TreasurySuggested(id, newTreasury);
    }

    /// @notice Accepts the treasury role for a given distribution.
    /// @param id The id of the merkle tree distribution.
    function acceptAsTreasury(Id id) external {
        require(msg.sender = pendingTreasuries[id], "UniversalRewardsDistributor: caller is not the pending treasury");
        treasuries[id] = pendingTreasuries[id];
        delete pendingTreasuries[id];
        emit TreasuryUpdated(id, treasuries[id]);
    }

    /// @notice Freeze a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param isFrozen Whether the distribution should be frozen or not.
    function freeze(Id id, bool isFrozen) external onlyOwner(id) {
        frozen[id] = isFrozen;
        emit Frozen(id, isFrozen);
    }

    /// @notice Force update the root of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev The distribution must be frozen before.
    function forceUpdateRoot(Id id, bytes32 newRoot) external onlyOwner(id) {
        require(frozen[id], "UniversalRewardsDistributor: not frozen");
        roots[id] = newRoot;
        emit RootUpdated(id, newRoot);
    }

    /// @notice Update the timelock of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function updateTimelock(Id id, uint256 newTimelock) external onlyOwner(id) {
        if(newTimelock < timelocks[id]) {
            require(
                pendingRoots[id].submittedAt == 0 || pendingRoots[id].submittedAt + timelocks[id] <= block.timestamp,
                "UniversalRewardsDistributor: timelock not expired"
            );
        }
        timelocks[id] = newTimelock;
        emit TimelockUpdated(id, newTimelock);
    }

    /// @notice Update the root updater of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function editRootUpdater(Id id, address updater, bool active) external onlyOwner(id) {
        rootUpdaters[id][updater] = active;
        emit RootUpdaterUpdated(id, updater, active);
    }

    /// @notice Revoke the pending root of a given distribution.
    /// @param id The id of the merkle tree distribution.
    /// @dev This function can only be called by the owner of the distribution at any time.
    function revokePendingRoot(Id id) external onlyOwner(id) {
        require(pendingRoots[id].submittedAt != 0, "UniversalRewardsDistributor: no pending root");
        delete pendingRoots[id];
        emit PendingRootRevoked(id);
    }
}
