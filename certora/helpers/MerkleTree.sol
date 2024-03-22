// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

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

contract MerkleTree {
    /* STORAGE */

    // The tree has no root because every node (and the nodes underneath) form a Merkle tree.
    // We use bytes32 as keys of the mapping so that leaves can have an identifier that is the hash of the address and the reward token.
    // This ensures that the same pair of address and reward token does not appear twice as a leaf in the tree.
    // For internal nodes the key is left arbitrary, so that the certificate generation can choose freely any bytes32 value (that is not already used).
    mapping(bytes32 => Node) internal tree;

    /* MAIN FUNCTIONS */

    function newLeaf(Leaf memory leaf) public {
        bytes32 id = keccak256(abi.encode(leaf.addr, leaf.reward));
        Node storage node = tree[id];
        require(id != 0, "id is the zero bytes");
        require(isEmpty(node), "leaf is not empty");
        require(leaf.value != 0, "value is zero");

        node.addr = leaf.addr;
        node.reward = leaf.reward;
        node.value = leaf.value;
        node.hashNode = keccak256(bytes.concat(keccak256(abi.encode(leaf.addr, leaf.reward, leaf.value))));
    }

    function newInternalNode(InternalNode memory internalNode) public {
        Node storage node = tree[internalNode.id];
        Node storage leftNode = tree[internalNode.left];
        Node storage rightNode = tree[internalNode.right];
        require(internalNode.id != 0, "id is zero bytes");
        require(isEmpty(node), "node is not empty");
        require(!isEmpty(leftNode), "left is empty");
        require(!isEmpty(rightNode), "right is empty");
        require(leftNode.hashNode <= rightNode.hashNode, "children are not pair sorted");

        node.left = internalNode.left;
        node.right = internalNode.right;
        node.hashNode = keccak256(abi.encode(leftNode.hashNode, rightNode.hashNode));
    }

    /* PURE AND VIEW FUNCTIONS */

    function isEmpty(Node memory node) public pure returns (bool) {
        return node.left == 0 && node.right == 0 && node.addr == address(0) && node.reward == address(0)
            && node.value == 0 && node.hashNode == 0;
    }

    function isEmpty(bytes32 id) public view returns (bool) {
        return isEmpty(tree[id]);
    }

    function getValue(address addr, address reward) public view returns (uint256) {
        bytes32 id = keccak256(abi.encode(addr, reward));
        return tree[id].value;
    }

    function getHash(bytes32 id) public view returns (bytes32) {
        return tree[id].hashNode;
    }

    // The specification of a well-formed tree is the following:
    //   - empty nodes are well-formed
    //   - correct identifiers of leaves
    //   - correct hashing of leaves and of internal nodes
    //   - internal nodes have their children pair sorted and not empty
    function isWellFormed(bytes32 id) public view returns (bool) {
        Node storage node = tree[id];

        if (isEmpty(node)) return true;

        if (node.left == 0 && node.right == 0) {
            bytes32 idLeaf = keccak256(abi.encode(node.addr, node.reward));
            return id == idLeaf
                && node.hashNode == keccak256(bytes.concat(keccak256(abi.encode(node.addr, node.reward, node.value))));
        } else {
            // Well-formed nodes have exactly 0 or 2 children.
            if (node.left == 0 || node.right == 0) return false;
            Node storage left = tree[node.left];
            Node storage right = tree[node.right];
            return !isEmpty(left) && !isEmpty(right) && left.hashNode <= right.hashNode
                && node.hashNode == keccak256(abi.encode(left.hashNode, right.hashNode));
        }
    }

    // Check that the nodes are well formed starting from `node` and going down the `tree`.
    // The `proof` is used to choose the path downward.
    function wellFormedPath(bytes32 id, bytes32[] memory proof) public view {
        for (uint256 i = proof.length;;) {
            require(isWellFormed(id));

            if (i == 0) break;

            bytes32 otherHash = proof[--i];

            bytes32 left = tree[id].left;
            bytes32 right = tree[id].right;

            id = getHash(left) == otherHash ? right : left;
        }
    }
}
