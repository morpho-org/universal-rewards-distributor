// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IUniversalRewardsDistributor} from "../src/interfaces/IUniversalRewardsDistributor.sol";
import {UniversalRewardsDistributor} from "../src/UniversalRewardsDistributor.sol";
import {EventsLib} from "../src/libraries/EventsLib.sol";

import {UrdFactory} from "../src/UrdFactory.sol";

import "../lib/forge-std/src/Test.sol";

contract UrdFactoryTest is Test {
    UrdFactory factory = new UrdFactory();

    function testCreateUrd(
        address randomCaller,
        address randomOwner,
        uint256 randomTimelock,
        bytes32 randomRoot,
        bytes32 randomIpfsHash,
        bytes32 randomSalt
    ) public {
        bytes32 initCodeHash = hashInitCode(
            type(UniversalRewardsDistributor).creationCode,
            abi.encode(randomOwner, randomTimelock, randomRoot, randomIpfsHash)
        );
        address urdAddress = computeCreate2Address(randomSalt, initCodeHash, address(factory));

        assertFalse(factory.isUrd(urdAddress), "!isUrd");

        vm.prank(randomCaller);
        vm.expectEmit(address(factory));
        emit EventsLib.UrdCreated(
            urdAddress, randomCaller, randomOwner, randomTimelock, randomRoot, randomIpfsHash, randomSalt
        );
        IUniversalRewardsDistributor urd = IUniversalRewardsDistributor(
            address(factory.createUrd(randomOwner, randomTimelock, randomRoot, randomIpfsHash, randomSalt))
        );

        assertEq(address(urd), urdAddress);
        assertTrue(factory.isUrd(address(urd)), "isUrd");
        assertEq(urd.ipfsHash(), randomIpfsHash);
        assertEq(urd.root(), randomRoot);
        assertEq(urd.owner(), randomOwner);
        assertEq(urd.timelock(), randomTimelock);
    }
}
