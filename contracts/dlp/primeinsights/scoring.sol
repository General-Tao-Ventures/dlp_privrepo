// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Permissions }      from "./permissions.sol";
import { ScoringStore }     from "./scoring_store.sol";
import { RewardsStore }     from "./rewards_store.sol";
import { Contributions }    from "./contributions.sol";

uint128 constant PERMISSION_EDIT_SCORING    = 0x08;
uint128 constant PERMISSION_EDIT_CATEGORIES = 0x10;

abstract contract Scoring is Permissions, Contributions, ScoringStore, RewardsStore
{
    function getCategoryScoringWeights(
        uint16 category
    ) public view returns (uint8[] memory scoring_weights)
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
    ) public view returns (bool)
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

    function getNumCategories() public view returns (uint16)
    {
        return uint16(_categories.length);
    }

    function getMetadataScores(
        uint256 contribution
    ) public view returns (uint8[][] memory)
    {
        return _contributionMetadataScores[contribution];
    }

    function getValidationScores(
        uint256 contribution
    ) public view returns (uint8[][] memory)
    {
        return _contributionValidationScores[contribution];
    }

    function getValidationWeight() public view returns (uint64)
    {
        return _validationWeight;
    }

    function setValidationWeight(
        uint64 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _validationWeight = weight;
    }

    function getMetadataWeight() public view returns (uint64)
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
}