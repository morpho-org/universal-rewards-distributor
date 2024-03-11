methods {
    function getRoot() external returns(bytes32) envfree;
    function getValue(address, address) external returns(uint256) envfree;
    function isEmpty(bytes32) external returns(bool) envfree;
    function isWellFormed(bytes32) external returns(bool) envfree;
}

invariant zeroIsEmpty()
    isEmpty(to_bytes32(0));

invariant rootIsZeroOrNotEmpty()
    getRoot() == to_bytes32(0) || !isEmpty(getRoot());

invariant wellFormed(bytes32 id)
    isWellFormed(id)
{ preserved {
    requireInvariant zeroIsEmpty();
  }
}
