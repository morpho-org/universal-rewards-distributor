// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


library FactoryEventsLib {
    /// @notice Emitted when a new URD is created.
    /// @param urd The address of the newly created URD.
    /// @param caller The address of the caller.
    /// @param owner The address of the URD owner.
    /// @param timelock The URD timelock.
    /// @param root The URD merkle tree's root.
    /// @param ipfsHash The URD merkle tree's ipfs hash.
    /// @param salt The salt used for CREATE2 opcode.
    event URDCreated(
        address indexed urd,
        address indexed caller,
        address indexed owner,
        uint256 timelock,
        bytes32 root,
        bytes32 ipfsHash,
        bytes32 salt
    );
}
