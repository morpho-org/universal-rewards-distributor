// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the caller is not the owner nor an updater.
    string internal constant CALLER_NOT_OWNER_OR_UPDATER = "caller is not the owner or updater";

    /// @notice Thrown when the caller is not the owner.
    string internal constant CALLER_NOT_OWNER = "caller is not the owner";

    /// @notice Thrown when there is not pending root.
    string internal constant NO_PENDING_ROOT = "no pending root";

    /// @notice Thrown when the timelock is not expired.
    string internal constant TIMELOCK_NOT_EXPIRED = "timelock is not expired";

    /// @notice Thrown when the root is not set.
    string internal constant ROOT_NOT_SET = "root is not set";

    /// @notice Thrown when the proof is invalid or expired when claiming rewards.
    string internal constant INVALID_PROOF_OR_EXPIRED = "invalid proof or expired";

    /// @notice Thrown when rewards have already been claimed.
    string internal constant ALREADY_CLAIMED = "already claimed";

    /// @notice Thrown when the value is already set.
    string internal constant ALREADY_SET = "already set";

    /// @notice Thrown when the submitted root (pending or not) is the same as the current one.
    string internal constant ROOT_ALREADY_SET = "root already set";
}
