// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

//import { UD2x18, ud2x18 } from "./prb-math/src/UD2x18.sol";
import { UD60x18, ud }  from "./prb-math/src/UD60x18.sol";
import { convert }      from "./prb-math/src/ud60x18/Conversions.sol";
import { Common }       from "./common.sol";
import { RewardsStore } from "./rewards_store.sol";
import { Scoring }      from "./scoring.sol";
import { Permissions }  from "./permissions.sol";

uint128 constant PERMISSION_EDIT_TOKENS             = 0x08;
uint128 constant PERMISSION_CLAIM_DLP_OWNER_REWARDS = 0x10;
abstract contract Rewards is Permissions, Common, RewardsStore, Scoring
{
    using SafeERC20 for IERC20; 

    function getNumRewardTokens() public view returns (uint64)
    {
        return uint64(_rewardTokens.length);
    }

    // unless admin adds 1 bazillion tokens we should be fine looping over all tokens
    // otherwise if admin insists on adding 1 bazillion tokens we can also use a mapping (token => index)
    event RewardTokenAdded(uint64 indexed epoch, address indexed token);
    function addRewardToken(
        address token
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_TOKENS)
    {
        require(token != address(0), "Invalid token");
        require(token.code.length > 0, "Token is not a contract");

        for (uint64 i = 0; i < getNumRewardTokens(); i++)
        {
            require(_rewardTokens[i] != token, "Token already added");
        }

        _rewardTokens.push(token);

        emit RewardTokenAdded(getCurrentEpoch(), token);
    }

    event RewardTokenRemoved(uint64 indexed epoch, address indexed token);
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
                _rewardTokens.pop();                                // remove last element

                emit RewardTokenRemoved(getCurrentEpoch(), token);
                return;
            }
        }

        revert("Token not found");
    }

    function isRewardTokenActive(
        address token
    ) public view returns (bool)
    {
        for (uint64 i = 0; i < getNumRewardTokens(); i++)
        {
            if (_rewardTokens[i] == token)
            {
                return true;
            }
        }

        return false;
    }

    function getTokenRewardForEpoch(
        address token,
        uint64 epoch
    ) public view returns (uint256)
    {
        return _rewardsForEpoch[epoch][token];
    }

    function calcRewardsForEpoch(
        address owner,
        uint64 epoch
    ) public view returns (uint256[] memory)
    {
        //require(canClaimRewards(from, epoch), "No rewards to claim");

        uint256 num_contributions = getNumContributionsByOwner(owner);
        require(num_contributions > 0, "No contributions");

        uint256 total_validation_score  = _contributionScoresTotalForEpoch[epoch].validation_score;
        uint256 total_metadata_score    = _contributionScoresTotalForEpoch[epoch].metadata_score;

        uint256[] memory reward_for_owner = new uint256[](getNumRewardTokens());
        if(total_validation_score > 0 || total_metadata_score > 0)
        {
            UD60x18 total_score = ud((total_validation_score + total_metadata_score) * 1e18);
            for (uint256 contribution = 0; contribution < num_contributions; contribution++)
            {
                uint256 contribution_id = _contributionsByOwner[owner][contribution];
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
                    uint256 reward_for_contribution = convert(base_reward_unit.mul(ud(score * 1e18)));

                    reward_for_owner[token] += reward_for_contribution;
                }
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

    event RewardsClaimed(address indexed to, uint64 indexed start_epoch, uint64 end_epoch, uint256[] rewards);
    function claimRewards() public
    {
        require(msg.sender != address(this), "Cannot claim rewards for the contract");
        require(getCurrentEpoch() > 0, "Rewards not started");

        address from                = msg.sender;
        uint64  claim_up_to_epoch   = getCurrentEpoch() - 1;
        require(canClaimRewards(from, claim_up_to_epoch), "No rewards to claim"); // -1 because we will unlock rewards for an epoch once the next epoch is started

        uint64              claim_start_epoch = findFirstEpochToClaim(from);
        uint256[] memory    rewards_for_owner = new uint256[](getNumRewardTokens());
        for (uint64 epoch = claim_start_epoch; epoch <= claim_up_to_epoch; epoch++) 
        {
            uint256[] memory rewards_for_epoch = calcRewardsForEpoch(msg.sender, epoch);
            for (uint64 token = 0; token < getNumRewardTokens(); token++)
            {
                rewards_for_owner[token] += rewards_for_epoch[token];
            }
        }

        transferRewards(from, rewards_for_owner);

        emit RewardsClaimed(from, claim_start_epoch, claim_up_to_epoch, rewards_for_owner);
        _lastClaimedEpoch[from] = claim_up_to_epoch;
    }

    function claimRewardsForSingleEpoch() public // incase claiming for all fails or something
    {
        require(msg.sender != address(this), "Cannot claim rewards for the contract");
        require(getCurrentEpoch() > 0, "Rewards not started");

        address from = msg.sender;
        require(canClaimRewards(from, getCurrentEpoch() - 1), "No rewards to claim");

        uint64              claim_epoch         = findFirstEpochToClaim(from);
        uint256[] memory    rewards_for_owner   = calcRewardsForEpoch(msg.sender, claim_epoch);
        transferRewards(from, rewards_for_owner);

        emit RewardsClaimed(from, claim_epoch, claim_epoch, rewards_for_owner);
        _lastClaimedEpoch[from]++;
    }

    event RewardsTransferred(address indexed to, uint256[] rewards);
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

        emit RewardsTransferred(to, rewards_for_owner);
    }

    event RewardAdded(uint64 indexed epoch, address indexed token, uint256 reward);
    event DLPOwnerRewardAdded(uint64 indexed epoch, address indexed token, uint256 reward);
    function addRewardForCurrentEpoch(
        address token,
        uint256 reward
    ) internal
    {
        uint256 owner_reward        = (reward / 2);
        uint256 contributor_reward  = owner_reward;
        if (reward % 2 == 1)
        {
            contributor_reward++; // arent we nice?
        }

        require((owner_reward + contributor_reward) == reward, "this shouldn't have happened");

        _rewardsForEpoch[getCurrentEpoch()][token] += contributor_reward;
        emit RewardAdded(getCurrentEpoch(), token, contributor_reward);

        _dlpOwnerRewardsForEpoch[getCurrentEpoch()][token] += owner_reward;
        emit DLPOwnerRewardAdded(getCurrentEpoch(), token, owner_reward);
    }

    function receiveToken(
        address token, 
        uint256 amount
    ) public
    {
        require(token != address(0), "Invalid token");
        require(amount >= 2, "Invalid amount");
        require(isRewardTokenActive(token), "Token not active");

        IERC20(token)
            .safeTransferFrom(msg.sender, address(this), amount);

        addRewardForCurrentEpoch(token, amount);
    }

    event DlpOwnerRewardsClaimed(address indexed to, uint64 indexed start_epoch, uint64 end_epoch, uint256[] rewards);
    function claimDlpOwnerRewards(
        address claim_to
    ) external permissionedCall(msg.sender, PERMISSION_CLAIM_DLP_OWNER_REWARDS)
    {
        require(getCurrentEpoch() > 0, "Rewards not started");
        require(claim_to != address(0), "Invalid address");

        uint64 claim_up_to_epoch = getCurrentEpoch() - 1;
        require(_dlpOwnerLastClaimedEpoch < claim_up_to_epoch, "No rewards to claim");
        
        uint256[] memory rewards_for_owner = new uint256[](getNumRewardTokens());
        for (uint64 epoch = _dlpOwnerLastClaimedEpoch == 0 ? 0 : _dlpOwnerLastClaimedEpoch + 1; epoch <= claim_up_to_epoch; epoch++)
        {
            for (uint64 token = 0; token < getNumRewardTokens(); token++)
            {
                rewards_for_owner[token] += _dlpOwnerRewardsForEpoch[epoch][_rewardTokens[token]];
            }
        }

        transferRewards(claim_to, rewards_for_owner);

        emit DlpOwnerRewardsClaimed(claim_to, _dlpOwnerLastClaimedEpoch, claim_up_to_epoch, rewards_for_owner);
        _dlpOwnerLastClaimedEpoch = claim_up_to_epoch;
    }

    function claimDlpOwnerRewardsForSingleEpoch(
        address claim_to
    ) external permissionedCall(msg.sender, PERMISSION_CLAIM_DLP_OWNER_REWARDS)
    {
        require(getCurrentEpoch() > 0, "Rewards not started");
        require(claim_to != address(0), "Invalid address");
        require(_dlpOwnerLastClaimedEpoch < getCurrentEpoch() - 1, "No rewards to claim");
        require(_dlpOwnerLastClaimedEpoch != 0, "Can not claim for single epoch yet."); // call claimDlpOwnerRewards first

        uint256[] memory    rewards_for_owner = new uint256[](getNumRewardTokens());
        uint64              claim_epoch       = _dlpOwnerLastClaimedEpoch + 1;
        for (uint64 token = 0; token < getNumRewardTokens(); token++)
        {
            rewards_for_owner[token] += _dlpOwnerRewardsForEpoch[claim_epoch][_rewardTokens[token]];
        }
        
        transferRewards(claim_to, rewards_for_owner);

        emit DlpOwnerRewardsClaimed(claim_to, _dlpOwnerLastClaimedEpoch, _dlpOwnerLastClaimedEpoch, rewards_for_owner);
        _dlpOwnerLastClaimedEpoch++;
    }
}