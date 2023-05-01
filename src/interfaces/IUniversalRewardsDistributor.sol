// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUniversalRewardsDistributor {
    /* EVENTS */

    event RootUpdated(bytes32 newRoot);

    event RewardsClaimed(address reward, address account, uint256 amount);

    /* ERRORS */

    error ProofInvalidOrExpired();

    error AlreadyClaimed();

    /* EXTERNAL */

    function updateRoot(bytes32 newRoot) external;

    function skim(address token) external;

    function claim(address account, address reward, uint256 claimable, bytes32[] calldata proof) external;
}
