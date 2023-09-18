// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniversalRewardsDistributor} from "src/interfaces/IUniversalRewardsDistributor.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";
import {FactoryEventsLib} from "src/libraries/FactoryEventsLib.sol";

import "@forge-std/Test.sol";
import {URDFactory} from "src/URDFactory.sol";

contract URDFactoryTest is Test {
    URDFactory factory = new URDFactory();

    function testURDFactoryGenerateCorrectly(
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
        emit FactoryEventsLib.URDCreated(urdAddress, randomCaller, randomOwner, randomTimelock, randomRoot, randomIpfsHash, randomSalt);
        address realAddress = factory.createURD(randomOwner, randomTimelock, randomRoot, randomIpfsHash, randomSalt);

        assertEq(realAddress, urdAddress);
        IUniversalRewardsDistributor distributor = IUniversalRewardsDistributor(realAddress);
        assertEq(distributor.ipfsHash(), randomIpfsHash);
        assertEq(distributor.root(), randomRoot);
        assertEq(distributor.owner(), randomOwner);
        assertEq(distributor.timelock(), randomTimelock);
    }

    function _precomputeAddress(bytes32 salt, bytes memory encodedParams) internal view returns (address) {
        bytes memory bytecode = abi.encodePacked(type(UniversalRewardsDistributor).creationCode, encodedParams);

        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecode)))))
        );
    }
}
