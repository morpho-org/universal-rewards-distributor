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

    /// @notice The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    mapping(uint256 => bytes32) public ipfsHashOf;

    /// @notice The `amount` of `reward` token already claimed by `account` for one given distribution.
    mapping(uint256 distributionId => mapping(address account => mapping(address reward => uint256 amount))) public
        claimed;

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

    /* EXTERNAL */

    /// @notice Proposes a new merkle tree root.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    /// @param ipfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    function proposeRoot(uint256 distributionId, bytes32 newRoot, bytes32 ipfsHash)
        external
        onlyUpdater(distributionId)
    {
        if (timelockOf[distributionId] == 0) {
            _forceUpdateRoot(distributionId, newRoot, ipfsHash);
        } else {
            pendingRootOf[distributionId] = PendingRoot(block.timestamp, newRoot, ipfsHash);
            emit RootProposed(distributionId, newRoot, ipfsHash);
        }
    }

    /// @notice Accepts the current pending merkle tree's root.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function acceptRootUpdate(uint256 distributionId) external {
        PendingRoot memory pendingRoot = pendingRootOf[distributionId];
        require(pendingRoot.submittedAt > 0, ErrorsLib.NO_PENDING_ROOT);
        require(block.timestamp >= pendingRoot.submittedAt + timelockOf[distributionId], ErrorsLib.TIMELOCK_NOT_EXPIRED);

        rootOf[distributionId] = pendingRoot.root;
        ipfsHashOf[distributionId] = pendingRoot.ipfsHash;
        delete pendingRootOf[distributionId];

        emit RootUpdated(distributionId, pendingRoot.root, pendingRoot.ipfsHash);
    }

    /// @notice Claims rewards.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(uint256 distributionId, address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
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
    /// @param initialIpfsHash The optional ipfs hash containing metadata about the root, if any (e.g. the merkle tree itself).
    /// @param initialOwner The initial owner for the new distribution.
    /// @param initialPendingTreasury The initial pending treasury for the new distribution.
    /// @dev The initial treasury is always `msg.sender`. The `initialPendingTreasury` can be set to `address(0)`.
    function createDistribution(
        uint256 initialTimelock,
        bytes32 initialRoot,
        bytes32 initialIpfsHash,
        address initialOwner,
        address initialPendingTreasury
    ) external returns (uint256 distributionId) {
        address owner = initialOwner == address(0) ? msg.sender : initialOwner;

        distributionId = nextDistributionId++;
        ownerOf[distributionId] = owner;
        treasuryOf[distributionId] = msg.sender;
        timelockOf[distributionId] = initialTimelock;

        emit DistributionCreated(distributionId, msg.sender, owner, initialTimelock);

        if (initialPendingTreasury != address(0)) {
            _proposeTreasury(distributionId, initialPendingTreasury);
        }

        if (initialRoot != bytes32(0)) {
            _forceUpdateRoot(distributionId, initialRoot, initialIpfsHash);
        }
    }

    /// @notice Proposes a new treasury address for a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newTreasury The new treasury address.
    function proposeTreasury(uint256 distributionId, address newTreasury) external onlyOwner(distributionId) {
        _proposeTreasury(distributionId, newTreasury);
    }

    /// @notice Accepts the treasury role for a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    function acceptAsTreasury(uint256 distributionId) external {
        require(msg.sender == pendingTreasuryOf[distributionId], ErrorsLib.CALLER_NOT_PENDING_TREASURY);

        treasuryOf[distributionId] = msg.sender;
        delete pendingTreasuryOf[distributionId];

        emit TreasuryUpdated(distributionId, msg.sender);
    }

    /// @notice Forces update the root of a given distribution.
    /// @param distributionId The distributionId of the merkle tree distribution.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev Set to bytes32(0) to remove the root.
    function forceUpdateRoot(uint256 distributionId, bytes32 newRoot, bytes32 newIpfsHash)
        external
        onlyOwner(distributionId)
    {
        _forceUpdateRoot(distributionId, newRoot, newIpfsHash);
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

    function _forceUpdateRoot(uint256 distributionId, bytes32 newRoot, bytes32 newIpfsHash) internal {
        rootOf[distributionId] = newRoot;
        ipfsHashOf[distributionId] = newIpfsHash;
        delete pendingRootOf[distributionId];
        emit RootUpdated(distributionId, newRoot, newIpfsHash);
    }

    function _proposeTreasury(uint256 distributionId, address newTreasury) internal {
        pendingTreasuryOf[distributionId] = newTreasury;
        emit TreasuryProposed(distributionId, newTreasury);
    }
}
