// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    string internal constant CALLER_NOT_OWNER_OR_UPDATER =
        "UniversalRewardsDistributor: caller is not the owner or updater";

    string internal constant CALLER_NOT_OWNER = "UniversalRewardsDistributor: caller is not the owner";

    string internal constant NO_PENDING_ROOT = "UniversalRewardsDistributor: no pending root";

    string internal constant TIMELOCK_NOT_EXPIRED = "UniversalRewardsDistributor: timelock is not expired";

    string internal constant ROOT_NOT_SET = "UniversalRewardsDistributor: root is not set";

    string internal constant INVALID_PROOF_OR_EXPIRED = "UniversalRewardsDistributor: invalid proof or expired";

    string internal constant ALREADY_CLAIMED = "UniversalRewardsDistributor: already claimed";
}
