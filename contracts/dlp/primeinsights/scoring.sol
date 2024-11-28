// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Permissions }      from "./permissions.sol";
import { ScoringStore }     from "./scoring_store.sol";
import { RewardsStore }     from "./rewards_store.sol";
import { Contributions }    from "./contributions.sol";
import { DataRegistry }     from "./data_reg.sol";

uint128 constant PERMISSION_EDIT_SCORING    = 0x10;
uint128 constant PERMISSION_EDIT_CATEGORIES = 0x20;

abstract contract Scoring is Permissions, Contributions, ScoringStore, RewardsStore, DataRegistry
{
    function getCategoryScoringWeights(
        uint16 category
    ) public view returns (uint8[] memory scoring_weights)
    {
        require(_categories[category].scoring_weights.length > 0, "Category not enabled");

        return _categories[category].scoring_weights;
    }

    event CategoryScoringWeightsSet(uint16 indexed category, uint8[] scoring_weights);
    function setCategoryScoringWeights(
        uint16          category,
        uint8[] memory  scoring_weights
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        require(category < getNumCategories(), "Invalid category");

        _categories[category].scoring_weights = scoring_weights;

        emit CategoryScoringWeightsSet(category, scoring_weights);
    }

    function isCategoryEnabled(
        uint16 category
    ) public view returns (bool)
    {
        return _categories[category].scoring_weights.length > 0 && !_categories[category].disabled;
    }

    event CategoryDisabled(uint16 indexed category);
    function disableCategory(
        uint16 category
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(category < getNumCategories(), "Invalid category");

        _categories[category].disabled = true;

        emit CategoryDisabled(category);
    }

    event CategoryEnabled(uint16 indexed category);
    function enableCategory(
        uint16 category
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(category < getNumCategories(), "Invalid category");

        _categories[category].disabled = false;

        emit CategoryEnabled(category);
    }

    event CategoryAdded(uint16 indexed category, uint8[] scoring_weights, bool disabled);
    function addCategory(
        uint8[] memory scoring_weights,
        bool    disabled
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(scoring_weights.length < 0xFFFF, "Invalid scoring weights");

        _categories.push(Category(scoring_weights, disabled));

        emit CategoryAdded(getNumCategories() - 1, scoring_weights, disabled);
    }

    function getNumCategories() public view returns (uint16)
    {
        return uint16(_categories.length);
    }

    function getMetadataScores(
        uint256 contribution,
        uint64 epoch
    ) public view returns (bytes memory)
    {
        //whole lotta gay
        string memory metadata = dr_getMetadata(contribution, 0);

        return bytes(metadata);
        //return _contributionMetadataScores[contribution];
    }

    function getValidationWeight() public view returns (uint64)
    {
        return _validationWeight;
    }

    event ValidationWeightSet(uint64 weight);
    function setValidationWeight(
        uint64 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _validationWeight = weight;

        emit ValidationWeightSet(weight);
    }

    function getMetadataWeight() public view returns (uint64)
    {
        return _metadataWeight;
    }

    event MetadataWeightSet(uint64 weight);
    function setMetadataWeight(
        uint64 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _metadataWeight = weight;

        emit MetadataWeightSet(weight);
    }

    function calculateTotalScoreForContribution(
        bytes memory metadata_scores
    ) internal view returns (uint64[] memory, uint64[] memory)
    {
        require(metadata_scores.length == getNumCategories() * 2, "Invalid metadata scores");

        //bool            has_valid_scores        = false;
        //uint8[][] memory    scoring_weights = new uint8[][](getNumCategories());
        //uint64              total_scoring_weights = 0;
        //for (uint16 category = 0; category < getNumCategories(); category++)
        //{
            //scoring_weights[category]   = getCategoryScoringWeights(category);
            //total_scoring_weights       += uint64(scoring_weights[category].length);
        //}

        uint64 validation_weight    = getValidationWeight();
        uint64 metadata_weight      = getMetadataWeight();
        uint64 validation_score_idx = uint64(metadata_scores.length / 2);

        uint64[] memory     validation_total_scores = new uint64[](getNumCategories());
        uint64[] memory     metadata_total_scores   = new uint64[](getNumCategories());
        for (uint16 category = 0; category < getNumCategories(); category++)
        {
            if (!isCategoryEnabled(category))
            {
                continue;
            }

            uint8 metadata_score    = uint8(metadata_scores[category]);
            uint8 validation_score  = uint8(metadata_scores[validation_score_idx + category]);
            if (metadata_score == 0 && validation_score == 0)
            {
                continue; 
            }

            validation_total_scores[category]   = uint64(validation_score) * validation_weight;
            metadata_total_scores[category]     = uint64(metadata_score) * metadata_weight;
        }

        //require(has_valid_scores, "No valid scores");

        return (validation_total_scores, metadata_total_scores);
    }

    event ScoreUpdated(uint256 indexed contribution, uint64 indexed epoch, uint16 indexed category, uint64 validation_score, uint64 metadata_score);
    function updateScoreForContributionAtEpoch(
        uint256 contribution,
        uint64  epoch
    ) internal
    {
        require(_contributionScoresUpdatedEpoch[contribution] < epoch, "Scores already updated");

        (uint64[] memory total_validation_scores, uint64[] memory total_metadata_scores) = calculateTotalScoreForContribution( 
            getMetadataScores(contribution, epoch)
        );

        for (uint16 category = 0; category < getNumCategories(); category++)
        {
            _contributionScores[contribution][epoch][category] = ContributionScore(
                total_validation_scores[category],
                total_metadata_scores[category]
            );

            emit ScoreUpdated(contribution, epoch, category, total_validation_scores[category], total_metadata_scores[category]);
        }

        _contributionScoresUpdatedEpoch[contribution] = epoch;
    }

    event TotalScoresUpdated(uint64 indexed epoch, uint64 validation_score, uint64 metadata_score);
    function updateScoresForContributionsAtEpoch(
        uint64 epoch
    ) internal
    {
        //for (uint256 contribution = 0; contribution < _contributions.length; contribution++)
        //{
        //    updateScoreForContributionAtEpoch(_contributions[contribution], epoch);
        //}

        for (uint256 contributor = 0; contributor < getNumContributors(); contributor++)
        {
            address _contributor = _contributors[contributor];

            updateScoreForContributionAtEpoch(
                _lastContribution[_contributor][_lastContributionEpoch[_contributor]], 
                epoch
            );
        }

        uint64 validation_score_for_epoch   = 0;
        uint64 metadata_score_for_epoch     = 0;
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

            validation_score_for_epoch  += total_validation_score;
            metadata_score_for_epoch    += total_metadata_score;
        }

        _contributionScoresTotalForEpoch[epoch].validation_score    = validation_score_for_epoch;
        _contributionScoresTotalForEpoch[epoch].metadata_score      = metadata_score_for_epoch;

        emit TotalScoresUpdated(epoch, validation_score_for_epoch, metadata_score_for_epoch);
    }
}