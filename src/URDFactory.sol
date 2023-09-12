// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {UniversalRewardsDistributor} from "./UniversalRewardsDistributor.sol";

/// @title URDFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract permits to create UniversalRewardsDistributor contracts, and to index them easily.
contract URDFactory {
    event URDCreated(address indexed urd, address indexed caller, address indexed owner);

    function createURD(
        address _initialOwner,
        uint256 _initialTimelock,
        bytes32 _initialRoot,
        bytes32 _initialIpfsHash,
        bytes32 salt
    ) public returns (address urd) {
        // it uses the CREATE2 opcode, so the address is deterministic
        urd = address(
            new UniversalRewardsDistributor{salt: salt}(
            _initialOwner,
            _initialTimelock,
            _initialRoot,
            _initialIpfsHash
            )
        );
        emit URDCreated(urd, msg.sender, _initialOwner);
    }
}
