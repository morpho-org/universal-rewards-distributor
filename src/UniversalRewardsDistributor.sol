// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {PendingRoot, IUniversalRewardsDistributor} from "./interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {MerkleProof} from "@openzeppelin/utils/cryptography/MerkleProof.sol";

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

    modifier onlyUpdater() {
        require(
            isUpdater[msg.sender] || msg.sender == owner,
            ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, ErrorsLib.CALLER_NOT_OWNER);
        _;
    }

    /// @notice Initializes the contract.
    /// @param _initialOwner The initial owner of the distribution.
    /// @param _initialTimelock The initial timelock of the distribution.
    /// @param _initialRoot The initial merkle tree's root.
    /// @param _initialIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    constructor(
    address _initialOwner,
    uint256 _initialTimelock,
    bytes32 _initialRoot,
    bytes32 _initialIpfsHash
    ) {
        owner = _initialOwner;
        timelock = _initialTimelock;

        if(_initialRoot != bytes32(0)) {
            _forceUpdateRoot(_initialRoot, _initialIpfsHash);
        }
    }


    /* EXTERNAL */

    /// @notice Proposes a new merkle tree root.
    /// @param newRoot The new merkle tree's root.
    /// @param newIpfsHash The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    function proposeRoot(bytes32 newRoot, bytes32 newIpfsHash)
        external
        onlyUpdater
    {
        if (timelock == 0) {
            _forceUpdateRoot(newRoot, newIpfsHash);
        } else {
            pendingRoot = PendingRoot(block.timestamp, newRoot, newIpfsHash);
            emit RootProposed(newRoot, newIpfsHash);
        }
    }

    /// @notice Accepts the current pending merkle tree's root.
    /// @dev This function can only be called after the timelock has expired.
    /// @dev Anyone can call this function.
    function acceptRootUpdate() external {
        PendingRoot memory pendingRootMem = pendingRoot;
        require(pendingRootMem.submittedAt > 0, ErrorsLib.NO_PENDING_ROOT);
        require(block.timestamp >= pendingRootMem.submittedAt + timelock, ErrorsLib.TIMELOCK_NOT_EXPIRED);

        root = pendingRootMem.root;
        ipfsHash = pendingRootMem.ipfsHash;
        delete pendingRoot;

        emit RootUpdated(pendingRoot.root, pendingRoot.ipfsHash);
    }

    /// @notice Claims rewards.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof)
        external
    {
        require(root != bytes32(0), ErrorsLib.ROOT_NOT_SET);
        require(
            MerkleProof.verifyCalldata(
                proof,
                root,
                keccak256(bytes.concat(keccak256(abi.encode(account, reward, claimable))))
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
    function forceUpdateRoot(bytes32 newRoot, bytes32 newIpfsHash)
        external
        onlyOwner
    {
        _forceUpdateRoot(newRoot, newIpfsHash);
    }

    /// @notice Updates the timelock of a given distribution.
    /// @param newTimelock The new timelock.
    /// @dev This function can only be called by the owner of the distribution.
    /// @dev If the timelock is reduced, it can only be updated after the timelock has expired.
    function updateTimelock(uint256 newTimelock) external onlyOwner {
        if (newTimelock < timelock) {
            PendingRoot memory pendingRootMemory = pendingRoot;
            require(
                pendingRootMemory.submittedAt == 0 || pendingRootMemory.submittedAt + timelock <= block.timestamp,
                ErrorsLib.TIMELOCK_NOT_EXPIRED
            );
        }

        timelock = newTimelock;
        emit TimelockUpdated(newTimelock);
    }

    /// @notice Updates the root updater of a given distribution.
    /// @param updater The new root updater.
    /// @param active Whether the root updater should be active or not.
    function updateRootUpdater(address updater, bool active)
        external
        onlyOwner
    {
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

    function setDistributionOwner(address newOwner) external onlyOwner {
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
