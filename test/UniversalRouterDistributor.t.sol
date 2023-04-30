// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@solmate/src/test/utils/mocks/MockERC20.sol";
import "src/UniversalRewardsDistributor.sol";

import "@forge-std/Test.sol";

contract UniversalRouterDistributor is Test {
	UniversalRewardsDistributor internal distributor;
	MockERC20 internal token;

	function setUp() public {
		distributor = new UniversalRewardsDistributor();
		token = new MockERC20("Token", "TKN", 18);
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
		deal(address(token), address(distributor), amount);

		distributor.skim(address(token));

		assertEq(ERC20(address(token)).balanceOf(address(distributor)), 0);
		assertEq(ERC20(address(token)).balanceOf(address(this)), amount);
	}

	function testSkimShouldReversWhenNotOwner(address caller) public {
		vm.assume(caller != distributor.owner());

		vm.prank(caller);
		vm.expectRevert("Ownable: caller is not the owner");
		distributor.skim(address(token));
	}
}