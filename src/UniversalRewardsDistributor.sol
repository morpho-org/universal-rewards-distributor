// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniversalRewardsDistributor} from "./interfaces/IUniversalRewardsDistributor.sol";

import {ERC20, SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Universal Rewards Distributor
/// @author MerlinEgalite
/// @notice This contract allows to distribute different rewards tokens to multiple accounts using a Merkle tree.
///         It is largely inspired by Morpho's current rewards distributor:
///         https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol
contract UniversalRewardsDistributor is IUniversalRewardsDistributor, Ownable {
    using SafeTransferLib for ERC20;

    /* STORAGE */

    /// @notice The merkle tree's root of the current rewards distribution.
    bytes32 public root;

    /// @notice The `amount` of `reward` token already claimed by `account`.
    mapping(address account => mapping(address reward => uint256 amount)) public claimed;

    /* EXTERNAL */

    /// @notice Updates the current merkle tree's root.
    /// @param newRoot The new merkle tree's root.
    function updateRoot(bytes32 newRoot) external onlyOwner {
        root = newRoot;
        emit RootUpdated(newRoot);
    }

    /// @notice Transfers the `token` balance from this contract to the owner.
    function skim(address token) external onlyOwner {
        ERC20(token).safeTransfer(msg.sender, ERC20(token).balanceOf(address(this)));
    }

    /// @notice Claims rewards.
    /// @param account The address to claim rewards for.
    /// @param reward The address of the reward token.
    /// @param claimable The overall claimable amount of token rewards.
    /// @param proof The merkle proof that validates this claim.
    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof) external {
        bytes32 candidateRoot = MerkleProof.processProof(proof, keccak256(abi.encodePacked(reward, account, claimable)));
        if (candidateRoot != root) revert ProofInvalidOrExpired();

        uint256 alreadyClaimed = claimed[account][reward];
        if (claimable <= alreadyClaimed) revert AlreadyClaimed();

        uint256 amount;
        unchecked {
            amount = claimable - alreadyClaimed;
        }

        claimed[account][reward] = claimable;

        ERC20(reward).safeTransfer(account, amount);
        emit RewardsClaimed(reward, account, amount);
    }
}
