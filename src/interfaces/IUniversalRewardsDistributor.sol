// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.4;

/// @notice The pending root struct for a Merkle tree distribution during the timelock.
struct PendingRoot {
    /// @dev The timestamp of the block in which the pending root was submitted.
    uint256 submittedAt;
    /// @dev The submitted pending root.
    bytes32 root;
    /// @dev The optional ipfs hash containing metadata about the root (e.g. the Merkle tree itself).
    bytes32 ipfsHash;
}

/// @title IUniversalRewardsDistributor
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice UniversalRewardsDistributor's interface.
interface IUniversalRewardsDistributor {
    function root() external view returns (bytes32);
    function owner() external view returns (address);
    function timelock() external view returns (uint256);
    function ipfsHash() external view returns (bytes32);
    function isUpdater(address) external view returns (bool);
    function pendingRoot() external view returns (uint256 submittedAt, bytes32 root, bytes32 ipfsHash);
    function claimed(address, address) external view returns (uint256);

    function submitRoot(bytes32 newRoot, bytes32 ipfsHash) external;

    function acceptRoot() external;
    function claim(address account, address reward, uint256 claimable, bytes32[] memory proof)
        external
        returns (uint256 amount);

    function setRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
    function setTimelock(uint256 newTimelock) external;
    function setRootUpdater(address updater, bool active) external;
    function revokeRoot() external;
    function setOwner(address newOwner) external;
}

interface IPendingRoot {
    function pendingRoot() external view returns (PendingRoot memory);
}
