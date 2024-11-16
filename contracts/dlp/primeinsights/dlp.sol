// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Rewards }      from "./rewards.sol";
import { Permissions }  from "./permissions.sol";
abstract contract DLP is Permissions, Rewards 
{
}