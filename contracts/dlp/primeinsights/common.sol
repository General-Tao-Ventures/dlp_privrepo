// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { CommonDataStore }  from "./common_store.sol";
import { Permissions }      from "./permissions.sol";

uint128 constant PERMISSION_SET_NATIVE_REWARD_TOKEN = 0x800;

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

    function getNativeRewardToken() public view returns (address)
    {
        return _nativeRewardToken;
    }

    function setNativeRewardToken(
        address new_native_reward_token
    ) external permissionedCall(msg.sender, PERMISSION_SET_NATIVE_REWARD_TOKEN)
    {
        _nativeRewardToken = new_native_reward_token;
    }
}
