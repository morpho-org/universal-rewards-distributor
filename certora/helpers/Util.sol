// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Util {
    function balanceOf(address reward, address user) external view returns (uint256) {
        return IERC20(reward).balanceOf(user);
    }
}
