// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@solmate/src/test/utils/mocks/MockERC20.sol";
import "src/UniversalRewardsDistributor.sol";

import {Merkle} from "@murky/src/Merkle.sol";

import "@forge-std/Test.sol";

contract UniversalRouterDistributor is Test {
	uint256 constant internal MAX_RECEIVERS = 20;

	UniversalRewardsDistributor internal distributor;
	Merkle merkle = new Merkle();
	MockERC20 internal token1;
	MockERC20 internal token2;

	function setUp() public {
		distributor = new UniversalRewardsDistributor();
		token1 = new MockERC20("Token1", "TKN1", 18);
		token2 = new MockERC20("Token2", "TKN2", 18);
	}

	function testUpdateRoot(bytes32 root) public {
		distributor.updateRoot(root);

		assertEq(distributor.root(), root);
	}

	function testUpdateRootShouldReversWhenNotOwner(bytes32 root, address caller) public {
		vm.assume(caller != distributor.owner());

		vm.prank(caller);
		vm.expectRevert("Ownable: caller is not the owner");
		distributor.updateRoot(root);
	}

	function testSkim(uint256 amount) public {
		deal(address(token1), address(distributor), amount);

		distributor.skim(address(token1));

		assertEq(ERC20(address(token1)).balanceOf(address(distributor)), 0);
		assertEq(ERC20(address(token1)).balanceOf(address(this)), amount);
	}

	function testSkimShouldReversWhenNotOwner(address caller) public {
		vm.assume(caller != distributor.owner());

		vm.prank(caller);
		vm.expectRevert("Ownable: caller is not the owner");
		distributor.skim(address(token1));
	}

	function testRewards(uint256 claimable, uint8 nbOfReceivers) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);
		uint256 boundedNbOfReceivers = bound(nbOfReceivers, 2, MAX_RECEIVERS);

		bytes32[] memory data = _setupRewards(claimable, boundedNbOfReceivers);
		_claimAndVerifyRewards(data, claimable);
	}

	function testRewardsWithUpdate(uint256 claimable1, uint256 claimable2, uint8 nbOfReceivers) public {
		claimable1 = bound(claimable1, 1 ether, type(uint128).max);
		claimable2 = bound(claimable2, claimable1 * 2, type(uint256).max);
		uint256 boundedNbOfReceivers = bound(nbOfReceivers, 2, MAX_RECEIVERS);

		bytes32[] memory data = _setupRewards(claimable1, boundedNbOfReceivers);
		_claimAndVerifyRewards(data, claimable1);

		data = _setupRewards(claimable2, boundedNbOfReceivers);
		_claimAndVerifyRewards(data, claimable2);
	}

	function testRewardsShouldRevertWhenAlreadyClaimed(uint256 claimable, uint8 nbOfReceivers) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);
		uint256 boundedNbOfReceivers = bound(nbOfReceivers, 2, MAX_RECEIVERS);

		bytes32[] memory data = _setupRewards(claimable, boundedNbOfReceivers);

		bytes32[] memory proof = merkle.getProof(data, 0);
		deal(address(token1), address(distributor), claimable);
		distributor.claim(vm.addr(1), address(token1), claimable, proof);

		vm.expectRevert(IUniversalRewardsDistributor.AlreadyClaimed.selector);
		distributor.claim(vm.addr(1), address(token1), claimable, proof);
	}

	function testRewardsShouldRevertWhenInvalidProofAndCorrectInputs(bytes32[] memory proof, uint256 claimable, uint8 nbOfReceivers) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);
		uint256 boundedNbOfReceivers = bound(nbOfReceivers, 2, MAX_RECEIVERS);

		_setupRewards(claimable, boundedNbOfReceivers);

		deal(address(token1), address(distributor), claimable);
		vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
		distributor.claim(vm.addr(1), address(token1), claimable, proof);
	}

	function testRewardsShouldRevertWhenValidProofButIncorrectInputs(address account, address reward, uint256 amount, uint256 claimable, uint8 nbOfReceivers) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);
		uint256 boundedNbOfReceivers = bound(nbOfReceivers, 2, MAX_RECEIVERS);

		bytes32[] memory data = _setupRewards(claimable, boundedNbOfReceivers);

		bytes32[] memory proof = merkle.getProof(data, 0);
		deal(address(token1), address(distributor), claimable);
		vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
		distributor.claim(account, reward, amount, proof);
	}

	function _setupRewards(uint256 claimable, uint256 size) internal returns (bytes32[] memory data) {
		data = new bytes32[](size);

		for (uint256 i = 0; i < size / 2; i++) {
			uint256 index = i + 1;
            data[i] = keccak256(abi.encodePacked(vm.addr(index), address(token1), uint256(claimable / index)));
        }
		for (uint256 i = size / 2; i < size; i++) {
			uint256 index = i + 1;
            data[i] = keccak256(abi.encodePacked(vm.addr(index), address(token2), uint256(claimable / index)));
        }

		bytes32 root = merkle.getRoot(data);
		distributor.updateRoot(root);
	}

	function _claimAndVerifyRewards(bytes32[] memory data, uint256 claimable) internal {
		for (uint256 i = 0; i < data.length / 2; i++) {
			bytes32[] memory proof = merkle.getProof(data, i);

			uint256 index = i + 1;
			uint256 claimableInput = claimable / index;
			uint256 claimableAdjusted = claimableInput - distributor.claimed(vm.addr(index), address(token1));
			deal(address(token1), address(distributor), claimableAdjusted);
			uint256 balanceBefore = ERC20(address(token1)).balanceOf(vm.addr(index));

			distributor.claim(vm.addr(index), address(token1), claimableInput, proof);

			assertEq(ERC20(address(token1)).balanceOf(address(distributor)), 0);
			assertEq(ERC20(address(token1)).balanceOf(vm.addr(index)), balanceBefore + claimableAdjusted);
		}
		for (uint256 i = data.length / 2; i < data.length; i++) {
			bytes32[] memory proof = merkle.getProof(data, i);

			uint256 index = i + 1;
			uint256 claimableInput = claimable / index;
			uint256 claimableAdjusted = claimableInput - distributor.claimed(vm.addr(index), address(token2));
			deal(address(token2), address(distributor), claimableAdjusted);
			uint256 balanceBefore = ERC20(address(token2)).balanceOf(vm.addr(index));

			distributor.claim(vm.addr(index), address(token2), claimableInput, proof);

			assertEq(ERC20(address(token2)).balanceOf(address(distributor)), 0);
			assertEq(ERC20(address(token2)).balanceOf(vm.addr(index)), balanceBefore + claimableAdjusted);
		}
	}
}