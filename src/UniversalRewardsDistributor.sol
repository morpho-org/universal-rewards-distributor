// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@solmate/src/utils/SafeTransferLib.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniversalRewardsDistributor is Ownable {
    using SafeTransferLib for ERC20;

    /* STORAGE */

    bytes32 public root;
    mapping(address => mapping(address => uint256)) public claimed;

    /* EVENTS */

    event RootUpdated(bytes32 newRoot);

    event RewardsClaimed(address reward, address account, uint256 amount);

    /* ERRORS */

    error ProofInvalidOrExpired();

    error AlreadyClaimed();

    /* EXTERNAL */

    function updateRoot(bytes32 newRoot) external onlyOwner {
        root = newRoot;
        emit RootUpdated(newRoot);
    }

    function skim(address token) external onlyOwner {
        ERC20(token).safeTransfer(msg.sender, ERC20(token).balanceOf(address(this)));
    }

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
