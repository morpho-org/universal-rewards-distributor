// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@forge-std/Script.sol";

import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";

contract DeployUniversalRewardsDistributor is Script {
	function run() public {
		vm.broadcast();
		console.log(address(new UniversalRewardsDistributor()));
	}
}
