using MerkleTrees as MerkleTrees;
using Util as Util;

methods {
    function root() external returns bytes32 envfree;
    function claimed(address, address) external returns(uint256) envfree;
    function claim(address, address, uint256, bytes32[]) external returns(uint256) envfree;

    function MerkleTrees.getValue(address, address) external returns(uint256) envfree;
    function MerkleTrees.getHash(address, address) external returns(bytes32) envfree;
    function MerkleTrees.wellFormedUpTo(address, address, uint256) external envfree;

    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);

    function Util.balanceOf(address, address) external returns(uint256) envfree;
}

// Check an account can only claim greater rewards each time.
rule noClaimAgain(address account, address reward, uint256 claimable, bytes32[] proof) {
    claim(account, reward, claimable, proof);

    assert claimable == claimed(account, reward);

    uint256 _claimable2;
    // Assume that the second claim is smaller or equal to the previous claimed amount.
    require (_claimable2 <= claimable);
    claim@withrevert(account, reward, _claimable2, proof);

    assert lastReverted;
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
    address tree; address node;

    // Assume that root is the hash of node in tree.
    require MerkleTrees.getHash(tree, node) == root();

    // No need to make sure that node is equal to currRoot : one can pass an internal node instead.

    // Assume that tree is well-formed.
    MerkleTrees.wellFormedUpTo(tree, node, 3);

    claim(account, reward, claimable, proof);

    assert claimable == MerkleTrees.getValue(tree, account);
}
