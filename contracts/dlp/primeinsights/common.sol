// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { CommonDataStore } from "./common_store.sol";
abstract contract Common is CommonDataStore
{
    function getCurrentEpoch() public view returns (uint64)
    {
        return _currentEpoch;
    }

    function nextEpoch() internal
    {
        _currentEpoch++;
    }
}