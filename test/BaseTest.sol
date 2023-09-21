// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";

import "@forge-std/Test.sol";

abstract contract BaseTest is Test {
    function _precomputeAddress(address sender, bytes memory encodedParams, bytes32 salt)
        internal
        pure
        returns (address)
    {
        bytes memory bytecode = abi.encodePacked(type(UniversalRewardsDistributor).creationCode, encodedParams);

        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), sender, salt, keccak256(bytecode))))));
    }
}
