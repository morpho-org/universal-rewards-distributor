// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IUniversalRewardsDistributor} from "src/interfaces/IUniversalRewardsDistributor.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

import {BaseTest} from "test/BaseTest.sol";
import {UrdFactory} from "src/UrdFactory.sol";

contract UrdFactoryTest is BaseTest {
    UrdFactory factory = new UrdFactory();

    function testCreateURD(
        address randomCaller,
        address randomOwner,
        uint256 randomTimelock,
        bytes32 randomRoot,
        bytes32 randomIpfsHash,
        bytes32 randomSalt
    ) public {
        bytes memory encodedParams = abi.encode(randomOwner, randomTimelock, randomRoot, randomIpfsHash);
        address urdAddress = _precomputeAddress(address(factory), encodedParams, randomSalt);

        vm.prank(randomCaller);
        vm.expectEmit(address(factory));
        emit EventsLib.UrdCreated(
            urdAddress, randomCaller, randomOwner, randomTimelock, randomRoot, randomIpfsHash, randomSalt
        );
        IUniversalRewardsDistributor urd =
            factory.createUrd(randomOwner, randomTimelock, randomRoot, randomIpfsHash, randomSalt);

        assertEq(address(urd), urdAddress);
        assertEq(urd.ipfsHash(), randomIpfsHash);
        assertEq(urd.root(), randomRoot);
        assertEq(urd.owner(), randomOwner);
        assertEq(urd.timelock(), randomTimelock);
    }
}
