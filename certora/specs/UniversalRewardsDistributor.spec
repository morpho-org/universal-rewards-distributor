// SPDX-License-Identifier: GPL-2.0-or-later

using MerkleTree as MerkleTree;
using Util as Util;

methods {
    function root() external returns bytes32 envfree;
    function claimed(address, address) external returns(uint256) envfree;
    function claim(address, address, uint256, bytes32[]) external returns(uint256) envfree;

    function MerkleTree.getValue(address, address) external returns(uint256) envfree;
    function MerkleTree.getHash(bytes32) external returns(bytes32) envfree;
    function MerkleTree.wellFormedPath(bytes32, bytes32[]) external envfree;

    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);

    function Util.balanceOf(address, address) external returns(uint256) envfree;
}

// Check an account claimed amount is correctly updated.
rule updatedClaimedAmount(address account, address reward, uint256 claimable, bytes32[] proof) {
    claim(account, reward, claimable, proof);

    assert claimable == claimed(account, reward);
}

// Check an account can only claim greater amounts each time.
rule increasingClaimedAmounts(address account, address reward, uint256 claimable, bytes32[] proof) {
    uint256 claimed = claimed(account, reward);

    claim(account, reward, claimable, proof);

    assert claimable > claimed;
}

// Check that claiming twice is equivalent to claiming once with the last amount.
rule claimTwice(address account, address reward, uint256 claim1, uint256 claim2) {
    storage initStorage = lastStorage;

    bytes32[] proof1; bytes32[] proof2;
    claim(account, reward, claim1, proof1);
    claim(account, reward, claim2, proof2);
    assert claim2 >= claim1;

    storage afterBothStorage = lastStorage;

    bytes32[] proof3;
    claim(account, reward, claim2, proof3) at initStorage;

    assert lastStorage == afterBothStorage;
}

// Check that the transferred amount is equal to the claimed amount minus the previous claimed amount.
rule transferredTokens(address account, address reward, uint256 claimable, bytes32[] proof) {
    // Assume that the rewards distributor itself is not receiving the tokens, to simplify this rule.
    require account != currentContract;

    uint256 balanceBefore = Util.balanceOf(reward, account);
    uint256 claimedBefore = claimed(account, reward);

    // Safe require because the sum is capped by the total supply.
    require balanceBefore + Util.balanceOf(reward, currentContract) < 2^256;

    claim(account, reward, claimable, proof);

    uint256 balanceAfter = Util.balanceOf(reward, account);

    assert balanceAfter - balanceBefore == claimable - claimedBefore;
}

rule claimCorrectness(address account, address reward, uint256 claimable, bytes32[] proof) {
    bytes32 node;

    // Assume that root is the hash of node in the tree.
    require MerkleTree.getHash(node) == root();

    // No need to make sure that node is equal to currRoot: one can pass an internal node instead.

    // Assume that the tree is well-formed.
    MerkleTree.wellFormedPath(node, proof);

    claim(account, reward, claimable, proof);

    assert claimable == MerkleTree.getValue(account, reward);
}
