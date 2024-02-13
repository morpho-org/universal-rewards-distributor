// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "./MerkleTreeLib.sol";

contract MerkleTree {
    using MerkleTreeLib for MerkleTreeLib.Node;
    using MerkleTreeLib for MerkleTreeLib.Tree;

    MerkleTreeLib.Tree tree;

    function newLeaf(address addr, address reward, uint256 value) public {
        tree.newLeaf(addr, reward, value);
    }

    function newInternalNode(bytes32 parent, bytes32 left, bytes32 right) public {
        tree.newInternalNode(parent, left, right);
    }

    function setRoot(bytes32 id) public {
        tree.setRoot(id);
    }

    function getRoot() public view returns (bytes32) {
        return tree.getRoot();
    }

    function getLeft(bytes32 id) public view returns (bytes32) {
        return tree.getLeft(id);
    }

    function getRight(bytes32 id) public view returns (bytes32) {
        return tree.getRight(id);
    }

    function getValue(address addr, address reward) public view returns (uint256) {
        return tree.getValue(addr, reward);
    }

    function getHash(bytes32 id) public view returns (bytes32) {
        return tree.getHash(id);
    }

    function isEmpty(bytes32 id) public view returns (bool) {
        return tree.nodes[id].isEmpty();
    }

    function isWellFormed(bytes32 id) public view returns (bool) {
        return tree.isWellFormed(id);
    }

    // Only go up to a given depth, to avoid CVL recursion protection.
    function wellFormedUpTo(bytes32 id, uint256 depth) public view {
        if (depth == 0) return;

        require(tree.isWellFormed(id));

        bytes32 left = tree.getLeft(id);
        bytes32 right = tree.getRight(id);
        if (left != 0) {
            wellFormedUpTo(left, depth - 1);
            wellFormedUpTo(right, depth - 1);
        }
    }
}
