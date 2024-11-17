// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

//import { UD2x18, ud2x18 } from "./prb-math/src/UD2x18.sol";
import { UD60x18, ud }  from "./prb-math/src/UD60x18.sol";
import { Common }       from "./common.sol";
import { RewardsStore } from "./rewards_store.sol";
import { Scoring }      from "./scoring.sol";
import { Permissions }  from "./permissions.sol";

uint128 constant PERMISSION_EDIT_TOKENS = 0x08;
abstract contract Rewards is Common, Permissions, RewardsStore, Scoring
{
    using SafeERC20 for IERC20; 

    function getNumRewardTokens() public view returns (uint64)
    {
        return uint64(_rewardTokens.length);
    }

    // unless admin adds 1 bazillion tokens we should be fine looping over all tokens
    // otherwise if admin insists on adding 1 bazillion tokens we can also use a mapping (token => index)
    function addRewardToken(
        address token
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_TOKENS)
    {
        require(Address.isContract(token), "Token is not a contract");
        require(token != address(0), "Invalid token");

        for (uint64 i = 0; i < getNumRewardTokens(); i++)
        {
            require(_rewardTokens[i] != token, "Token already added");
        }

        _rewardTokens.push(token);
    }

    function removeRewardToken(
        address token
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_TOKENS)
    {
        require(token != address(0), "Invalid token");

        uint64 num_tokens = getNumRewardTokens();
        for (uint64 i = 0; i < num_tokens; i++)
        {
            if (_rewardTokens[i] == token)
            {
                _rewardTokens[i] = _rewardTokens[num_tokens - 1];   // copy last element to current position
                _rewardTokens.pop();                              // remove last element

                return;
            }
        }

        revert("Token not found");
    }

    function getTokenRewardForEpoch(
        address token,
        uint64 epoch
    ) public view returns (uint256)
    {
        return _rewardsForEpoch[epoch][token];
    }

    function calcRewardsForEpoch(
        uint64 epoch
    ) internal view returns (uint256[] memory)
    {
        address from = msg.sender;
        //require(canClaimRewards(from, epoch), "No rewards to claim");

        uint64 num_contributions = getNumContributionsByOwner(from);
        require(num_contributions > 0, "No contributions");

        uint256 total_validation_score  = _contributionScoresTotalForEpoch[epoch].validation_score;
        uint256 total_metadata_score    = _contributionScoresTotalForEpoch[epoch].metadata_score;

        UD60x18 total_score = ud((total_validation_score + total_metadata_score) * 1e18);

        uint256[] memory reward_for_owner = new uint256[](getNumRewardTokens());
        for (uint64 contribution = 0; contribution < num_contributions; contribution++)
        {
            uint256 contribution_id = _contributionsByOwner[from][contribution];
            for (uint64 token = 0; token < getNumRewardTokens(); token++)
            {
                uint256 reward = getTokenRewardForEpoch(_rewardTokens[token], epoch);
                if (reward == 0)
                {
                    continue;
                }

                uint256 score = 0;
                for (uint16 category = 0; category < getNumCategories(); category++)
                {
                    score += _contributionScores[contribution_id][epoch][category].validation_score 
                            + _contributionScores[contribution_id][epoch][category].metadata_score;
                }

                UD60x18 base_reward_unit        = ud(reward * 1e18).div(total_score);
                uint256 reward_for_contribution = base_reward_unit.mul(ud(score)).intoUint256();

                reward_for_owner[token] += reward_for_contribution;
            }
        }

        return reward_for_owner;
    }

    function findFirstEpochToClaim(
        address addr
    ) public view returns (uint64)
    {
        uint64 last_claimed_epoch = _lastClaimedEpoch[addr];
        
        return last_claimed_epoch == 0 ? _firstDistributionEpoch[addr] : last_claimed_epoch + 1;
    }

    function canClaimRewards(
        address addr, 
        uint64  curr_epoch
    ) public view returns (bool)
    {
        return _lastClaimedEpoch[addr] < curr_epoch;
    }

    function claimRewards() external
    {
        require(getCurrentEpoch() > 0, "Rewards not started");

        address from                = msg.sender;
        uint64  claim_up_to_epoch   = getCurrentEpoch() - 1;
        require(canClaimRewards(from, claim_up_to_epoch), "No rewards to claim"); // -1 because we will unlock rewards for an epoch once the next epoch is started

        uint256[] memory rewards_for_owner = new uint256[](getNumRewardTokens());
        for (uint64 epoch = findFirstEpochToClaim(from); epoch <= claim_up_to_epoch; epoch++) 
        {
            uint256[] memory rewards_for_epoch = calcRewardsForEpoch(epoch);
            for (uint64 token = 0; token < getNumRewardTokens(); token++)
            {
                rewards_for_owner[token] += rewards_for_epoch[token];
            }
        }

        transferRewards(from, rewards_for_owner);

        _lastClaimedEpoch[from] = claim_up_to_epoch;
    }

    function claimRewardsForSingleEpoch() external // incase claiming for all fails or something
    {
        require(getCurrentEpoch() > 0, "Rewards not started");

        address from = msg.sender;
        require(canClaimRewards(from, getCurrentEpoch() - 1), "No rewards to claim");

        uint256[] memory rewards_for_owner = calcRewardsForEpoch(findFirstEpochToClaim(from));
        transferRewards(from, rewards_for_owner);

        _lastClaimedEpoch[from]++;
    }

    function transferRewards(
        address             to,
        uint256[] memory    rewards_for_owner
    ) internal
    {
        require(rewards_for_owner.length == getNumRewardTokens(), "Invalid reward array");

        for (uint64 token = 0; token < getNumRewardTokens(); token++)
        {
            if (rewards_for_owner[token] == 0)
            {
                continue;
            }

            IERC20(_rewardTokens[token])
                .safeTransfer(to, rewards_for_owner[token]);
        }
    }

    function addRewardForCurrentEpoch(
        address token,
        uint256 reward
    ) internal
    {
        _rewardsForEpoch[getCurrentEpoch()][token] += reward;
    }
}