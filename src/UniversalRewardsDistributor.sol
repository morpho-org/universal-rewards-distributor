// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {PendingRoot, IUniversalRewardsDistributor} from "./interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title UniversalRewardsDistributor
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract enables the distribution of various reward tokens to multiple accounts using different permissionless Merkle trees.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor {
    using SafeTransferLib for ERC20;

    /// @notice The merkle tree's roots of a given distribution.
    bytes32 public root;

    /// @notice The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    bytes32 public ipfsHash;

    /// @notice The `amount` of `reward` token already claimed by `account` for one given distribution.
    mapping(address => mapping(address => uint256)) public claimed;

    /// @notice The address that can update the distribution parameters, and freeze a root.
    address public owner;

    /// @notice The addresses that can update the merkle tree's root for a given distribution.
    mapping(address => bool) public isUpdater;

    /// @notice The timelock before a root update
    uint256 public timelock;

    /// @notice The pending root of the distribution.
    /// @dev If the pending root is set, the root can be updated after the timelock has expired.
    /// @dev The pending root is skipped if the timelock is set to 0.
    PendingRoot public pendingRoot;

    modifier onlyOwnerOrUpdater() {
        require(isUpdater[msg.sender] || msg.sender == owner, ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.CALLER_NOT_OWNER);
        _;
    }

    /// @notice Initializes the contract.
    /// @param initialOwner The initial owner of the contract.
    /// @param initialTimelock The initial timelock of the contract.
    /// @param initialRoot The initial merkle tree's root.
    /// @param initialIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    constructor(address initialOwner, uint256 initialTimelock, bytes32 initialRoot, bytes32 initialIpfsHash) {
        owner = initialOwner;
        timelock = initialTimelock;

        if (initialRoot != bytes32(0)) {
            _setRoot(initialRoot, initialIpfsHash);
        }
    }

    /* EXTERNAL */

    /// @notice Proposes a new merkle tree root.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    function proposeRoot(bytes32 newRoot, bytes32 newIpfsHash) external onlyOwnerOrUpdater {
        if (timelock == 0) {
            _setRoot(newRoot, newIpfsHash);
        } else {
            pendingRoot = PendingRoot(block.timestamp, newRoot, newIpfsHash);
            emit EventsLib.RootProposed(newRoot, newIpfsHash);
        }
    }

    /// @notice Accepts the current pending merkle tree's root.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function acceptRoot() external {
        require(pendingRoot.submittedAt > 0, ErrorsLib.NO_PENDING_ROOT);
        require(block.timestamp >= pendingRoot.submittedAt + timelock, ErrorsLib.TIMELOCK_NOT_EXPIRED);

        root = pendingRoot.root;
        ipfsHash = pendingRoot.ipfsHash;
        emit EventsLib.RootSet(pendingRoot.root, pendingRoot.ipfsHash);

        delete pendingRoot;
    }

    /// @notice Claims rewards.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    /// @return amount The amount of reward token claimed.
    /// @dev Anyone can claim rewards on behalf of an account.
    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
        returns (uint256 amount)
    {
        require(root != bytes32(0), ErrorsLib.ROOT_NOT_SET);
        require(
            MerkleProof.verifyCalldata(
                proof, root, keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
            ),
            ErrorsLib.INVALID_PROOF_OR_EXPIRED
        );

        amount = claimable - claimed[account][reward];

        require(amount > 0, ErrorsLib.ALREADY_CLAIMED);

        claimed[account][reward] = claimable;

        ERC20(reward).safeTransfer(account, amount);

        emit EventsLib.Claimed(account, reward, amount);
    }

    /// @notice Forces update the root of a given distribution.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev Set to bytes32(0) to remove the root.
    function setRoot(bytes32 newRoot, bytes32 newIpfsHash) external onlyOwner {
        _setRoot(newRoot, newIpfsHash);
    }

    /// @notice Updates the timelock of a given distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function setTimelock(uint256 newTimelock) external onlyOwner {
        if (newTimelock < timelock) {
            PendingRoot memory pendingRootMem = pendingRoot;
            require(
                pendingRootMem.submittedAt == 0 || pendingRootMem.submittedAt + timelock <= block.timestamp,
                ErrorsLib.TIMELOCK_NOT_EXPIRED
            );
        }

        timelock = newTimelock;
        emit EventsLib.TimelockSet(newTimelock);
    }

    /// @notice Updates the root updater of a given distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function setRootUpdater(address updater, bool active) external onlyOwner {
        isUpdater[updater] = active;
        emit EventsLib.RootUpdaterSet(updater, active);
    }

    /// @notice Revokes the pending root of a given distribution.
    /// @dev This function can only be called by the owner of the distribution at any time.
    function revokeRoot() external onlyOwner {
        require(pendingRoot.submittedAt != 0, ErrorsLib.NO_PENDING_ROOT);

        delete pendingRoot;
        emit EventsLib.RootRevoked();
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
        emit EventsLib.OwnerSet(msg.sender, newOwner);
    }

    function _setRoot(bytes32 newRoot, bytes32 newIpfsHash) internal {
        root = newRoot;
        ipfsHash = newIpfsHash;
        delete pendingRoot;
        emit EventsLib.RootSet(newRoot, newIpfsHash);
    }
}
