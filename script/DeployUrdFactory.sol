// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./ConfiguredScript.sol";

/// @dev Warning: keys must be ordered alphabetically.
struct DeployUrdFactoryConfig {
    bytes32 salt;
}

contract DeployUrdFactory is ConfiguredScript {
    function run(string memory network) public returns (DeployUrdFactoryConfig memory config) {
        config = abi.decode(_init(network), (DeployUrdFactoryConfig));

        // Deploy UrdFactory
        _deployCreate2Code("UrdFactory", hex"", config.salt);
    }
}
