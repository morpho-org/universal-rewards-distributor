pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {UrdFactory} from "src/UrdFactory.sol";

contract DeployUrd is Script {
    function run() public {
        vm.startBroadcast();
        UrdFactory factory = new UrdFactory();
        address urd = factory.createUrd(msg.sender, 1 days, bytes32(0), bytes32(0), bytes32(0));
        console.log(urd);

        vm.stopBroadcast();
    }
}
