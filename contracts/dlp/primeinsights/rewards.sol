// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

//import { UD2x18, ud2x18 } from "./prb-math/src/UD2x18.sol";
import { UD60x18, ud }                              from "./prb-math/src/UD60x18.sol";
import { IRewards }                                 from "./interfaces/irewards.sol";
import { RewardsStoreV1 }                           from "./rewards_store.sol";
import { Permissions, PERMISSION_FIRST_AVAILABLE }  from "./permissions.sol";


uint128 constant PERMISSION_EDIT_TOKENS     = PERMISSION_FIRST_AVAILABLE;
uint128 constant PERMISSION_EDIT_SCORING    = PERMISSION_FIRST_AVAILABLE << 1;
uint128 constant PERMISSION_EDIT_CATEGORIES = PERMISSION_FIRST_AVAILABLE << 2;

abstract contract Rewards is IRewards, Permissions, RewardsStoreV1
{
    using SafeERC20 for IERC20; 

    function getNumTokens() internal view returns (uint64)
    {
        return uint64(_tokens.length);
    }

    // unless admin adds 1 bazillion tokens we should be fine looping over all tokens
    // otherwise if admin insists on adding 1 bazillion tokens we can also use a mapping (token => index)
    function addToken(
        address token
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_TOKENS)
    {
        require(token != address(0), "Invalid token");

        for (uint64 i = 0; i < getNumTokens(); i++)
        {
            require(_tokens[i] != token, "Token already added");
        }

        _tokens.push(token);
    }

    function removeToken(
        address token
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_TOKENS)
    {
        require(token != address(0), "Invalid token");

        uint64 num_tokens = getNumTokens();
        for (uint64 i = 0; i < num_tokens; i++)
        {
            if (_tokens[i] == token)
            {
                _tokens[i] = _tokens[num_tokens - 1];   // copy last element to current position
                _tokens.pop();                              // remove last element

                return;
            }
        }

        revert("Token not found");
    }

    function getCategoryScoringWeights(
        uint16 category
    ) internal view returns (uint8[] memory scoring_weights)
    {
        require(_categories[category].scoring_weights.length > 0, "Category not enabled");

        return _categories[category].scoring_weights;
    }

    function setCategoryScoringWeights(
        uint16          category,
        uint8[] memory  scoring_weights
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        require(category < getNumCategories(), "Invalid category");

        _categories[category].scoring_weights = scoring_weights;
    }

    function isCategoryEnabled(
        uint16 category
    ) internal view returns (bool)
    {
        return _categories[category].scoring_weights.length > 0 && !_categories[category].disabled;
    }

    function disableCategory(
        uint16 category
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(category < getNumCategories(), "Invalid category");

        _categories[category].disabled = true;
    }

    function addCategory(
        uint8[] memory scoring_weights,
        bool    disabled
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(scoring_weights.length < 0xFFFF, "Invalid scoring weights");

        _categories.push(Category(scoring_weights, disabled));
    }

    function getNumCategories() internal view returns (uint16)
    {
        return uint16(_categories.length);
    }

    function getMetadataScores(
        uint256 contribution
    ) internal view returns (uint8[][] memory)
    {
        return _contributionMetadataScores[contribution];
    }

    function getValidationScores(
        uint256 contribution
    ) internal view returns (uint8[][] memory)
    {
        return _contributionValidationScores[contribution];
    }

    function getValidationWeight() internal view returns (uint64)
    {
        return _validationWeight;
    }

    function setValidationWeight(
        uint64 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _validationWeight = weight;
    }

    function getMetadataWeight() internal view returns (uint64)
    {
        return _metadataWeight;
    }

    function setMetadataWeight(
        uint64 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _metadataWeight = weight;
    }

    function calculateTotalScoreForContribution(
        uint8[][] memory metadata_scores, 
        uint8[][] memory validation_scores
    ) internal view returns (uint64[] memory, uint64[] memory)
    {
        require(metadata_scores.length == validation_scores.length, "Invalid scores");
        require(metadata_scores.length == getNumCategories(), "Invalid scores");

        uint64 validation_weight = getValidationWeight();
        uint64 metadata_weight   = getMetadataWeight();

        bool            has_valid_scores        = false;
        uint64[] memory validation_total_scores = new uint64[](getNumCategories());
        uint64[] memory metadata_total_scores   = new uint64[](getNumCategories());
        for (uint16 category = 0; category < getNumCategories(); category++)
        {
            if (!isCategoryEnabled(category))
            {
                continue;
            }

            uint8[] memory scoring_weights = getCategoryScoringWeights(category);
            require(metadata_scores[category].length == validation_scores[category].length, "Invalid scores");
            require(metadata_scores[category].length == scoring_weights.length, "Invalid scores");
                
            for (uint16 scoring_weight_idx = 0; scoring_weight_idx < scoring_weights.length; scoring_weight_idx++)
            {
                uint8 metadata_score    = metadata_scores[category][scoring_weight_idx];
                uint8 validation_score  = validation_scores[category][scoring_weight_idx];
                if (metadata_score == 0 && validation_score == 0)
                {
                    continue;
                }

                validation_total_scores[category]   += (uint64(validation_score) * scoring_weights[scoring_weight_idx]) * validation_weight;
                metadata_total_scores[category]     += (uint64(metadata_score)   * scoring_weights[scoring_weight_idx]) * metadata_weight;

                has_valid_scores                    = true;
            }
        }

        require(has_valid_scores, "No valid scores");

        return (validation_total_scores, metadata_total_scores);
    }

    function updateScoreForContributionAtEpoch(
        uint256 contribution,
        uint64  epoch
    ) internal
    {
        require(_contributionScoresUpdatedEpoch[contribution] < epoch, "Scores already updated");

        (uint64[] memory total_validation_scores, uint64[] memory total_metadata_scores) = calculateTotalScoreForContribution( 
            getMetadataScores(contribution),
            getValidationScores(contribution)
        );

        for (uint16 category = 0; category < getNumCategories(); category++)
        {
            _contributionScores[contribution][epoch][category] = ContributionScore(
                total_validation_scores[category],
                total_metadata_scores[category]
            );
        }

        _contributionScoresUpdatedEpoch[contribution] = epoch;
    }

    function updateScoresForContributionsAtEpoch(
        uint64 epoch
    ) internal
    {
        for (uint256 contribution = 0; contribution < _contributions.length; contribution++)
        {
            updateScoreForContributionAtEpoch(_contributions[contribution], epoch);
        }

        _contributionScoresTotalForEpoch[epoch].validation_score    = 0;
        _contributionScoresTotalForEpoch[epoch].metadata_score      = 0;
        for (uint16 category = 0; category < getNumCategories(); category++)
        {
            uint64 total_validation_score   = 0;
            uint64 total_metadata_score     = 0;
            for (uint256 contribution = 0; contribution < _contributions.length; contribution++)
            {
                uint64 validation_score = _contributionScores[contribution][epoch][category].validation_score;
                uint64 metadata_score   = _contributionScores[contribution][epoch][category].metadata_score;
                if(validation_score > 0 || metadata_score > 0)
                {
                    total_validation_score  += validation_score;
                    total_metadata_score    += metadata_score;

                    address owner = _contributionOwner[_contributions[contribution]];
                    if (_firstDistributionEpoch[owner] == 0)
                    {
                        _firstDistributionEpoch[owner] = epoch;
                    }
                }
            }

            _contributionScoresTotalForEpoch[epoch].validation_score    += total_validation_score;
            _contributionScoresTotalForEpoch[epoch].metadata_score      += total_metadata_score;
        }
    }

    function getTokenRewardForEpoch(
        address token,
        uint64 epoch
    ) internal view returns (uint256)
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

        uint256[] memory reward_for_owner = new uint256[](getNumTokens());
        for (uint64 contribution = 0; contribution < num_contributions; contribution++)
        {
            uint256 contribution_id = _contributionsByOwner[from][contribution];
            for (uint64 token = 0; token < getNumTokens(); token++)
            {
                uint256 reward = getTokenRewardForEpoch(_tokens[token], epoch);
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
    ) internal view returns (uint64)
    {
        uint64 last_claimed_epoch = _lastClaimedEpoch[addr];
        
        return last_claimed_epoch == 0 ? _firstDistributionEpoch[addr] : last_claimed_epoch + 1;
    }

    function canClaimRewards(
        address addr, 
        uint64  curr_epoch
    ) internal view returns (bool)
    {
        return _lastClaimedEpoch[addr] < curr_epoch;
    }

    function claimRewards() external
    {
        require(getCurrentEpoch() > 0, "Rewards not started");

        address from                = msg.sender;
        uint64  claim_up_to_epoch   = getCurrentEpoch() - 1;
        require(canClaimRewards(from, claim_up_to_epoch), "No rewards to claim"); // -1 because we will unlock rewards for an epoch once the next epoch is started

        uint256[] memory rewards_for_owner = new uint256[](getNumTokens());
        for (uint64 epoch = findFirstEpochToClaim(from); epoch <= claim_up_to_epoch; epoch++) 
        {
            uint256[] memory rewards_for_epoch = calcRewardsForEpoch(epoch);
            for (uint64 token = 0; token < getNumTokens(); token++)
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
        require(rewards_for_owner.length == getNumTokens(), "Invalid reward array");

        for (uint64 token = 0; token < getNumTokens(); token++)
        {
            if (rewards_for_owner[token] == 0)
            {
                continue;
            }

            IERC20(_tokens[token])
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