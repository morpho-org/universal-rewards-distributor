// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console2.sol";

abstract contract ConfiguredScript is Script {
    using stdJson for string;

    string internal configPath;

    function _init(string memory network) internal returns (bytes memory) {
        vm.createSelectFork(vm.rpcUrl(network));

        console2.log("Running script on network %s using %s...", network, msg.sender);

        return _loadConfig(network);
    }

    function _loadConfig(string memory network) internal returns (bytes memory) {
        configPath = string.concat("script/config/", network, ".json");

        return vm.parseJson(vm.readFile(configPath));
    }

    function _deployCreate2Code(string memory what, bytes memory args, bytes32 salt) internal returns (address addr) {
        bytes memory bytecode = abi.encodePacked(vm.getCode(string.concat(what, ".sol")), args);

        vm.broadcast();
        assembly ("memory-safe") {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        require(addr != address(0), "create2 deployment failed");

        console2.log("Deployed %s at: %s", what, addr);
    }
}
