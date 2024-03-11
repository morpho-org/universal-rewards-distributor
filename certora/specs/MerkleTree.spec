// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    function getValue(address, address) external returns(uint256) envfree;
    function isEmpty(bytes32) external returns(bool) envfree;
    function isWellFormed(bytes32) external returns(bool) envfree;
}

invariant zeroIsEmpty()
    isEmpty(to_bytes32(0));

invariant wellFormed(bytes32 id)
    isWellFormed(id)
{ preserved {
    requireInvariant zeroIsEmpty();
  }
}
