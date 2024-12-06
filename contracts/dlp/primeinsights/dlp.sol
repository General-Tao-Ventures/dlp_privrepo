// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { Permissions }      from "./permissions.sol";
import { DLPInterface }     from "./interface.sol";

uint128 constant PERMISSION_FINISH_EPOCH            = 0x400;
uint128 constant PERMISSION_SET_NATIVE_REWARD_TOKEN = 0x800;

abstract contract DLP is Permissions, Common, Contributions, Rewards, DLPInterface
{
    function _finishEpoch() internal
    {
        require(!_paused, "Contract is paused");
        updateScoresForContributionsAtEpoch(getCurrentEpoch());

        advanceEpoch();
    }

    function finishEpoch() external permissionedCall(msg.sender, PERMISSION_FINISH_EPOCH)
    {
        _finishEpoch();
    }

    event NativeRewardTokenChanged(uint64 indexed epoch, address new_reward_token);
    function setNativeRewardToken(
        address new_native_reward_token
    ) external permissionedCall(msg.sender, PERMISSION_SET_NATIVE_REWARD_TOKEN)
    {
        require(isRewardTokenActive(new_native_reward_token), "Token is not active.");
        _nativeRewardToken = new_native_reward_token;

        emit NativeRewardTokenChanged(getCurrentEpoch(), new_native_reward_token);
    }

    function addRewardsForContributors(uint256 reward_amount) external
    {
        require(getNativeRewardToken() != address(0), "Native reward token not set");
        require(getRewardSender() == msg.sender, "Only reward sender can add rewards");

        receiveToken(getNativeRewardToken(), reward_amount);

        _finishEpoch();
    }
}
