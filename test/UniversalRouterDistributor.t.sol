// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@solmate/src/test/utils/mocks/MockERC20.sol";
import "src/UniversalRewardsDistributor.sol";

import { Merkle } from "murky/Merkle.sol";

import "@forge-std/Test.sol";

contract UniversalRouterDistributor is Test {
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

	function testTree(uint256 claimable) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);

		bytes32[] memory data = new bytes32[](10);
		_setupData(data, claimable);

		bytes32 root = merkle.getRoot(data);
		distributor.updateRoot(root);

		for (uint256 i = 0; i < 5; i++) {
			bytes32[] memory proof = merkle.getProof(data, i);
			deal(address(token1), address(distributor), claimable / (i + 1));
			distributor.claim(vm.addr(i + 1), address(token1), claimable / (i + 1), proof);

			assertEq(ERC20(address(token1)).balanceOf(address(distributor)), 0);
			assertEq(ERC20(address(token1)).balanceOf(vm.addr(i + 1)), claimable / (i + 1));
		}
		for (uint256 i = 5; i < 10; i++) {
			bytes32[] memory proof = merkle.getProof(data, i);
			deal(address(token2), address(distributor), claimable / (i + 1));
			distributor.claim(vm.addr(i + 1), address(token2), claimable / (i + 1), proof);

			assertEq(ERC20(address(token2)).balanceOf(address(distributor)), 0);
			assertEq(ERC20(address(token2)).balanceOf(vm.addr(i + 1)), claimable / (i + 1));
		}
	}

	function testTreeShouldRevertWhenAlreadyClaimed(uint256 claimable) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);

		bytes32[] memory data = new bytes32[](10);
		_setupData(data, claimable);

		bytes32 root = merkle.getRoot(data);
		distributor.updateRoot(root);

		bytes32[] memory proof = merkle.getProof(data, 0);
		deal(address(token1), address(distributor), claimable);
		distributor.claim(vm.addr(1), address(token1), claimable, proof);

		vm.expectRevert(IUniversalRewardsDistributor.AlreadyClaimed.selector);
		distributor.claim(vm.addr(1), address(token1), claimable, proof);
	}

	function testTreeShouldRevertWhenInvalidProofAndCorrectInputs(bytes32[] memory proof, uint256 claimable) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);

		bytes32[] memory data = new bytes32[](10);
		_setupData(data, claimable);

		bytes32 root = merkle.getRoot(data);
		distributor.updateRoot(root);

		deal(address(token1), address(distributor), claimable);
		vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
		distributor.claim(vm.addr(1), address(token1), claimable, proof);
	}

	function testTreeShouldRevertWhenValidProofButIncorrectInputs(address account, address reward, uint256 amount, uint256 claimable) public {
		claimable = bound(claimable, 1 ether, type(uint256).max);

		bytes32[] memory data = new bytes32[](10);
		_setupData(data, claimable);

		bytes32 root = merkle.getRoot(data);
		distributor.updateRoot(root);

		bytes32[] memory proof = merkle.getProof(data, 0);
		deal(address(token1), address(distributor), claimable);
		vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
		distributor.claim(account, reward, amount, proof);
	}

	function _setupData(bytes32[] memory data, uint256 claimable) internal view {
		for (uint256 i = 0; i < data.length / 2; i++) {
            data[i] = keccak256(abi.encodePacked(vm.addr(i + 1), address(token1), uint256(claimable / (i + 1))));
        }
		for (uint256 i = data.length / 2; i < data.length; i++) {
            data[i] = keccak256(abi.encodePacked(vm.addr(i + 1), address(token2), uint256(claimable / (i + 1))));
        }
	}
}