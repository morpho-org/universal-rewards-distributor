// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    string internal constant CALLER_NOT_OWNER_OR_UPDATER = "caller is not the owner or updater";

    string internal constant CALLER_NOT_OWNER = "caller is not the owner";

    string internal constant NO_PENDING_ROOT = "no pending root";

    string internal constant TIMELOCK_NOT_EXPIRED = "timelock is not expired";

    string internal constant ROOT_NOT_SET = "root is not set";

    string internal constant INVALID_PROOF_OR_EXPIRED = "invalid proof or expired";

    string internal constant ALREADY_CLAIMED = "already claimed";
}
