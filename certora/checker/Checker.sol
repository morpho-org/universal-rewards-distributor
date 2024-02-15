// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.0;

import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../helpers/MerkleTreeLib.sol";
import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/StdJson.sol";

contract Checker is Test {
    using MerkleTreeLib for MerkleTreeLib.Tree;
    using stdJson for string;

    MerkleTreeLib.Tree public tree;

    struct Leaf {
        bytes32 id;
        bytes32 addr;
        bytes32 reward;
        uint256 value;
    }

    struct InternalNode {
        bytes32 id;
        bytes32 left;
        bytes32 right;
    }

    function testVerifyCertificate() public {
        string memory projectRoot = vm.projectRoot();
        string memory path = string.concat(projectRoot, "/certificate.json");
        string memory json = vm.readFile(path);

        uint256 leafLength = abi.decode(json.parseRaw(".leafLength"), (uint256));
        Leaf memory leaf;
        for (uint256 i; i < leafLength; i++) {
            leaf = abi.decode(json.parseRaw(string.concat(".leaf[", Strings.toString(i), "]")), (Leaf));
            tree.newLeaf(address(bytes20(leaf.addr)), address(bytes20(leaf.reward)), leaf.value);
        }

        uint256 nodeLength = abi.decode(json.parseRaw(".nodeLength"), (uint256));
        InternalNode memory node;
        for (uint256 i; i < nodeLength; i++) {
            node = abi.decode(json.parseRaw(string.concat(".node[", Strings.toString(i), "]")), (InternalNode));
            tree.newInternalNode(node.id, node.left, node.right);
        }

        assertTrue(!tree.isEmpty(node.id), "empty root");

        bytes32 root = abi.decode(json.parseRaw(".root"), (bytes32));
        assertEq(tree.getHash(node.id), root, "mismatched roots");
    }
}
