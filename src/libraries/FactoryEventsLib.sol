// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library FactoryEventsLib {
    /// @notice Emitted when a new Urd is created.
    /// @param urd The address of the newly created Urd.
    /// @param caller The address of the caller.
    /// @param owner The address of the Urd owner.
    /// @param timelock The Urd timelock.
    /// @param root The Urd merkle tree's root.
    /// @param ipfsHash The Urd merkle tree's ipfs hash.
    /// @param salt The salt used for CREATE2 opcode.
    event UrdCreated(
        address indexed urd,
        address indexed caller,
        address indexed owner,
        uint256 timelock,
        bytes32 root,
        bytes32 ipfsHash,
        bytes32 salt
    );
}
