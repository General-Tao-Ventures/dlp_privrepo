// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { CommonDataStore }  from "./common_store.sol";
import { Permissions }      from "./permissions.sol";

abstract contract Common is CommonDataStore, Permissions
{
    function getCurrentEpoch() public view returns (uint64)
    {
        return _currentEpoch;
    }

    event EpochAdvanced(uint64 indexed epoch);
    function advanceEpoch() internal
    {
        _currentEpoch++;

        emit EpochAdvanced(_currentEpoch);
    }

    function isPaused() public view returns (bool)
    {
        return _paused;
    }

    function getNativeRewardToken() public view returns (address)
    {
        return _nativeRewardToken;
    }
}
