// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { CommonDataStore }  from "./common_store.sol";
import { Permissions }      from "./permissions.sol";

uint128 constant PERMISSION_UPDATE_REWARD_SENDER = 0x2000;

abstract contract Common is CommonDataStore, Permissions
{
    address internal _rewardSender;

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

    function getRewardSender() public view returns (address)
    {
        return _rewardSender;
    }

    function setRewardSender(
        address new_reward_sender
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_REWARD_SENDER)
    {
        _rewardSender = new_reward_sender;
    }
}
