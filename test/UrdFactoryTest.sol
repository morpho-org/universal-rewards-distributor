// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IUniversalRewardsDistributor} from "src/interfaces/IUniversalRewardsDistributor.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

import "@forge-std/Test.sol";
import {UrdFactory} from "src/UrdFactory.sol";

contract UrdFactoryTest is Test {
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
        address urdAddress = _precomputeAddress(randomSalt, encodedParams);

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

    function _precomputeAddress(bytes32 salt, bytes memory encodedParams) internal view returns (address) {
        bytes memory bytecode = abi.encodePacked(type(UniversalRewardsDistributor).creationCode, encodedParams);

        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecode)))))
        );
    }
}
