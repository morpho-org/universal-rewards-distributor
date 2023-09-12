// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IDistribution} from "./interfaces/IDistribution.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";

/// @title UniversalRewardsDistributor
/// @author Morpho Labs
/// @notice This contract enables the distribution of various reward tokens to multiple accounts using different permissionless Merkle trees.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor {
    event DistributionCreated(
        address indexed distribution, address indexed caller, address indexed owner, uint256 initialTimelock
    );

    /* EXTERNAL */

    /// @notice Creates a new distribution.
    /// @param initialTimelock The initial timelock for the new distribution.
    /// @param initialRoot The initial merkle tree's root for the new distribution.
    /// @param initialIpfsHash The optional ipfs hash containing metadata about the root, if any (e.g. the merkle tree itself).
    /// @param initialOwner The initial owner for the new distribution.
    /// @dev The initial treasury is always `msg.sender`. The `initialPendingTreasury` can be set to `address(0)`.
    function createDistribution(
        uint256 initialTimelock,
        bytes32 initialRoot,
        bytes32 initialIpfsHash,
        address initialOwner
    ) external returns (address distribution) {
        address owner = initialOwner == address(0) ? msg.sender : initialOwner;

        distribution = address(new Distribution(owner, initialTimelock, initialRoot, initialIpfsHash));

        emit DistributionCreated(distribution, msg.sender, owner, initialTimelock);
    }
}

contract Distribution is IDistribution {
    using SafeTransferLib for ERC20;

    /// @notice The address that can update the distribution parameters, and freeze a root.
    address public owner;

    /// @notice The merkle tree's roots of a given distribution.
    bytes32 public root;

    /// @notice The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    bytes32 public ipfsHash;

    /// @notice The timelock for a given distribution.
    uint256 public timelockOf;

    /// @notice The `amount` of `reward` token already claimed by `account` for one given distribution.
    mapping(address account => mapping(address reward => uint256 amount)) public claimed;

    /// @notice The addresses that can update the merkle tree's root for a given distribution.
    mapping(address => bool) public isUpdater;

    /// @notice The pending root for a given distribution.
    /// @dev If the pending root is set, the root can be updated after the timelock has expired.
    /// @dev The pending root is skipped if the timelock is set to 0.
    PendingRoot public pendingRoot;

    modifier onlyUpdater() {
        require(isUpdater[msg.sender] || msg.sender == owner, ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.CALLER_NOT_OWNER);
        _;
    }

    constructor(address initialOwner, uint256 initialTimelock, bytes32 initialRoot, bytes32 initialIpfsHash) {
        owner = initialOwner;
        timelockOf = initialTimelock;
        root = initialRoot;
        ipfsHash = initialIpfsHash;
    }

    /// @notice Proposes a new merkle tree root.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    function proposeRoot(bytes32 newRoot, bytes32 newIpfsHash) external onlyUpdater {
        if (timelockOf == 0) {
            _forceUpdateRoot(newRoot, ipfsHash);
        } else {
            pendingRoot = PendingRoot(block.timestamp, newRoot, newIpfsHash);
            emit RootProposed(newRoot, ipfsHash);
        }
    }

    /// @notice Accepts the current pending merkle tree's root.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function acceptRootUpdate() external {
        PendingRoot memory pendingRoot = pendingRoot;
        require(pendingRoot.submittedAt > 0, ErrorsLib.NO_PENDING_ROOT);
        require(block.timestamp >= pendingRoot.submittedAt + timelockOf, ErrorsLib.TIMELOCK_NOT_EXPIRED);

        root = pendingRoot.root;
        ipfsHash = pendingRoot.ipfsHash;
        delete pendingRoot;

        emit RootUpdated(pendingRoot.root, pendingRoot.ipfsHash);
    }

    /// @notice Claims rewards.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof) external {
        require(root != bytes32(0), ErrorsLib.ROOT_NOT_SET);
        require(
            MerkleProof.verifyCalldata(
                proof, root, keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
            ),
            ErrorsLib.INVALID_PROOF_OR_EXPIRED
        );

        uint256 amount = claimable - claimed[account][reward];

        require(amount > 0, ErrorsLib.ALREADY_CLAIMED);

        claimed[account][reward] = claimable;

        ERC20(reward).safeTransfer(account, amount);

        emit RewardsClaimed(account, reward, amount);
    }

    /// @notice Forces update the root of a given distribution.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev Set to bytes32(0) to remove the root.
    function forceUpdateRoot(bytes32 newRoot, bytes32 newIpfsHash) external onlyOwner {
        _forceUpdateRoot(newRoot, newIpfsHash);
    }

    /// @notice Updates the timelock of a given distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function updateTimelock(uint256 newTimelock) external onlyOwner {
        if (newTimelock < timelockOf) {
            PendingRoot memory pendingRoot = pendingRoot;
            require(
                pendingRoot.submittedAt == 0 || pendingRoot.submittedAt + timelockOf <= block.timestamp,
                ErrorsLib.TIMELOCK_NOT_EXPIRED
            );
        }

        timelockOf = newTimelock;
        emit TimelockUpdated(newTimelock);
    }

    /// @notice Updates the root updater of a given distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function updateRootUpdater(address updater, bool active) external onlyOwner {
        isUpdater[updater] = active;
        emit RootUpdaterUpdated(updater, active);
    }

    /// @notice Revokes the pending root of a given distribution.
    /// @dev This function can only be called by the owner of the distribution at any time.
    function revokePendingRoot() external onlyOwner {
        require(pendingRoot.submittedAt != 0, ErrorsLib.NO_PENDING_ROOT);

        delete pendingRoot;
        emit PendingRootRevoked();
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
        emit DistributionOwnerSet(msg.sender, newOwner);
    }

    function _forceUpdateRoot(bytes32 newRoot, bytes32 newIpfsHash) internal {
        root = newRoot;
        ipfsHash = newIpfsHash;
        delete pendingRoot;
        emit RootUpdated(newRoot, newIpfsHash);
    }
}
