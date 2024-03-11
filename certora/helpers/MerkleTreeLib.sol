// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

library MerkleTreeLib {
    using MerkleTreeLib for Node;

    struct Leaf {
        address addr;
        address reward;
        uint256 value;
    }

    struct InternalNode {
        bytes32 id;
        bytes32 left;
        bytes32 right;
    }

    struct Node {
        bytes32 left;
        bytes32 right;
        address addr;
        address reward;
        uint256 value;
        // hash of [addr, reward, value] for leaves, and [left.hash, right.hash] for internal nodes.
        bytes32 hashNode;
    }

    function isEmpty(Node memory node) internal pure returns (bool) {
        return node.left == 0 && node.right == 0 && node.addr == address(0) && node.reward == address(0)
            && node.value == 0 && node.hashNode == 0;
    }

    struct Tree {
        mapping(bytes32 => Node) nodes;
        bytes32 root;
    }

    function newLeaf(Tree storage tree, Leaf memory leaf) internal {
        // The following identifier is used as the key to create a new leaf.
        // This ensures that the same pair of address and reward does not appear twice in the tree.
        bytes32 id = keccak256(abi.encode(leaf.addr, leaf.reward));
        Node storage node = tree.nodes[id];
        require(id != 0, "id is the zero bytes");
        require(node.isEmpty(), "leaf is not empty");
        require(leaf.value != 0, "value is zero");

        node.addr = leaf.addr;
        node.reward = leaf.reward;
        node.value = leaf.value;
        node.hashNode = keccak256(bytes.concat(keccak256(abi.encode(leaf.addr, leaf.reward, leaf.value))));
    }

    function newInternalNode(Tree storage tree, InternalNode memory internalNode) internal {
        Node storage node = tree.nodes[internalNode.id];
        Node storage leftNode = tree.nodes[internalNode.left];
        Node storage rightNode = tree.nodes[internalNode.right];
        require(internalNode.id != 0, "id is zero bytes");
        require(node.isEmpty(), "node is not empty");
        require(!leftNode.isEmpty(), "left is empty");
        require(!rightNode.isEmpty(), "right is empty");
        require(leftNode.hashNode <= rightNode.hashNode, "children are not pair sorted");

        node.left = internalNode.left;
        node.right = internalNode.right;
        node.hashNode = keccak256(abi.encode(leftNode.hashNode, rightNode.hashNode));
    }

    function setRoot(Tree storage tree, bytes32 id) internal {
        require(!tree.nodes[id].isEmpty(), "node is empty");
        tree.root = id;
    }

    // The specification of a well-formed tree is the following:
    //   - empty nodes are well-formed
    //   - correct identifiers of leaves
    //   - correct hashing of leaves and of internal nodes
    //   - internal nodes have their children pair sorted and not empty
    function isWellFormed(Tree storage tree, bytes32 id) internal view returns (bool) {
        Node storage node = tree.nodes[id];

        if (node.isEmpty()) return true;

        if (node.left == 0 && node.right == 0) {
            bytes32 idLeaf = keccak256(abi.encode(node.addr, node.reward));
            return id == idLeaf
                && node.hashNode == keccak256(bytes.concat(keccak256(abi.encode(node.addr, node.reward, node.value))));
        } else {
            // Well-formed nodes have exactly 0 or 2 children.
            if (node.left == 0 || node.right == 0) return false;
            Node storage left = tree.nodes[node.left];
            Node storage right = tree.nodes[node.right];
            return !left.isEmpty() && !right.isEmpty() && left.hashNode <= right.hashNode
                && node.hashNode == keccak256(abi.encode(left.hashNode, right.hashNode));
        }
    }

    function isEmpty(Tree storage tree, bytes32 id) internal view returns (bool) {
        return tree.nodes[id].isEmpty();
    }

    function getRoot(Tree storage tree) internal view returns (bytes32) {
        return tree.root;
    }

    function getLeft(Tree storage tree, bytes32 id) internal view returns (bytes32) {
        return tree.nodes[id].left;
    }

    function getRight(Tree storage tree, bytes32 id) internal view returns (bytes32) {
        return tree.nodes[id].right;
    }

    function getValue(Tree storage tree, address addr, address reward) internal view returns (uint256) {
        bytes32 id = keccak256(abi.encode(addr, reward));
        return tree.nodes[id].value;
    }

    function getHash(Tree storage tree, bytes32 id) internal view returns (bytes32) {
        return tree.nodes[id].hashNode;
    }
}
