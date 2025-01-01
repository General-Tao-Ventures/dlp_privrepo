// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { Common }           from "./common.sol";
import { Permissions }      from "./permissions.sol";
import { StorageV1 }        from "./storagev1.sol";
import { Contributions }    from "./contributions.sol";
import { DataRegistry }     from "./data_reg.sol";

uint128 constant PERMISSION_EDIT_SCORING    = 0x20;
uint128 constant PERMISSION_EDIT_CATEGORIES = 0x40;

abstract contract Scoring is StorageV1, Permissions, DataRegistry, Contributions
{
    function isCategoryEnabled(
        uint16 category
    ) public view returns (bool)
    {
        return !(_categories[category].disabled);
    }

    event CategoryDisabled(uint16 indexed category);
    function disableCategory(
        uint16 category
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(category < getNumCategories());
        _categories[category].disabled = true;

        emit CategoryDisabled(category);
    }

    event CategoryEnabled(uint16 indexed category);
    function enableCategory(
        uint16 category
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(category < getNumCategories());
        _categories[category].disabled = false;

        emit CategoryEnabled(category);
    }

    event CategoryAdded(uint16 indexed category, string name, bool disabled);
    function addCategory(
        string memory   name,
        bool            disabled
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_CATEGORIES)
    {
        require(getNumCategories() < 0xFFFF);
        _categories.push(Category(name, disabled));

        emit CategoryAdded(getNumCategories() - 1, name, disabled);
    }

    function getNumCategories() public view returns (uint16)
    {
        return uint16(_categories.length);
    }

    function _hexCharToUint8(bytes1 hexChar) internal pure returns (uint8) {
        uint8 byteValue = uint8(hexChar);
        if (byteValue >= 48 && byteValue <= 57) {
            return byteValue - 48; // Convert '0'-'9' to 0-9
        } else if (byteValue >= 65 && byteValue <= 70) {
            return byteValue - 65 + 10; // Convert 'A'-'F' to 10-15
        } else if (byteValue >= 97 && byteValue <= 102) {
            return byteValue - 97 + 10; // Convert 'a'-'f' to 10-15
        } else {
            revert("Invalid hex character"); // Handle invalid characters
        }
    }

    function getMetadataScores(
        uint256 contribution
    ) public view returns (uint16[] memory)
    {
       //whole lotta gay
        uint16 num_categories = getNumCategories();
        uint16[] memory metadata_scores = new uint16[](num_categories * 2);

        bytes memory metadata          = bytes(dr_getMetadata(contribution, 1));
        uint16 category_scores_offset = 7; // {"_": "b69c0000000000000000000000000000"}
        
        if(metadata.length <= category_scores_offset + 2)
        {
            return metadata_scores;
        }

        uint16 category_scores_length = uint16(metadata.length) - category_scores_offset - 2;
        if(category_scores_length % 4 != 0) // 2 chars per uint8 * 2
        {
            return metadata_scores;
        }

        for(uint16 category = 0; category < num_categories; category++) // length / sizeof(uint16) / 2
        {
            if (category >= num_categories)
            {
                break;
            }

            if (!isCategoryEnabled(category))
            {
                continue;
            }
            
            metadata_scores[category] = 16 * _hexCharToUint8(metadata[category_scores_offset + category * 2])
                                        + _hexCharToUint8(metadata[category_scores_offset + category * 2 + 1]);
                                        
            metadata_scores[num_categories + category] = 16 * _hexCharToUint8(metadata[category_scores_offset + (category + num_categories) * 2 ])
                                                        + _hexCharToUint8(metadata[category_scores_offset + (category + num_categories) * 2 + 1]);
        }

        return metadata_scores;
    }

    function getValidationWeight() public view returns (uint16)
    {
        return _validationWeight;
    }

    event ValidationWeightSet(uint16 weight);
    function setValidationWeight(
        uint16 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _validationWeight = weight;

        emit ValidationWeightSet(weight);
    }

    function getMetadataWeight() public view returns (uint16)
    {
        return _metadataWeight;
    }

    event MetadataWeightSet(uint16 weight);
    function setMetadataWeight(
        uint16 weight
    ) external permissionedCall(msg.sender, PERMISSION_EDIT_SCORING)
    {
        _metadataWeight = weight;

        emit MetadataWeightSet(weight);
    }

    function calculateTotalScoreForContribution(
        uint16[] memory metadata_scores
    ) internal view returns (uint64[] memory, uint64[] memory)
    {
        require(metadata_scores.length == getNumCategories() * 2, "Invalid scores");

        uint64 validation_weight    = getValidationWeight();
        uint64 metadata_weight      = getMetadataWeight();
        uint64 validation_score_idx = uint64(metadata_scores.length / 2);

        uint64[] memory validation_total_scores = new uint64[](getNumCategories());
        uint64[] memory metadata_total_scores   = new uint64[](getNumCategories());
        
        uint16 num_categories = getNumCategories();
        for (uint16 category = 0; category < num_categories; category++)
        {
            if (!isCategoryEnabled(category))
            {
                continue;
            }

            uint16 metadata_score    = metadata_scores[category];
            uint16 validation_score  = metadata_scores[validation_score_idx + category];
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
        require(_contributionScoresUpdatedEpoch[contribution] < epoch, "Already updated");

        (uint64[] memory total_validation_scores, uint64[] memory total_metadata_scores) = calculateTotalScoreForContribution( 
            getMetadataScores(contribution)
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

    event TotalScoresUpdated(uint64 indexed epoch, uint256 validation_score, uint256 metadata_score);
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
            address contributor_addr    = _contributors[contributor];
            uint256 contribution        = _lastContribution[contributor_addr][_lastContributionEpoch[contributor_addr]];
            
            if (contribution != 0)
            {
                updateScoreForContributionAtEpoch(
                    contribution, 
                    epoch
                );
            }
        }

        uint256 validation_score_for_epoch   = 0;
        uint256 metadata_score_for_epoch     = 0;
        for (uint16 category = 0; category < getNumCategories(); category++)
        {
            uint64 total_validation_score   = 0;
            uint64 total_metadata_score     = 0;
            for (uint256 contributor = 0; contributor < getNumContributors(); contributor++)
            {
                address contributor_addr    = _contributors[contributor];
                uint256 contribution        = _lastContribution[contributor_addr][_lastContributionEpoch[contributor_addr]];

                uint64 validation_score     = _contributionScores[contribution][epoch][category].validation_score;
                uint64 metadata_score       = _contributionScores[contribution][epoch][category].metadata_score;
                if(validation_score > 0 || metadata_score > 0)
                {
                    total_validation_score  += validation_score;
                    total_metadata_score    += metadata_score;

                    //address owner = _contributionOwner[_contributions[contribution]];
                    if (_firstDistributionEpoch[contributor_addr] == 0)
                    {
                        _firstDistributionEpoch[contributor_addr] = epoch;
                    }
                }
            }

            validation_score_for_epoch  += uint256(total_validation_score);
            metadata_score_for_epoch    += uint256(total_metadata_score);
        }

        require(validation_score_for_epoch > 0 || metadata_score_for_epoch > 0, "No scores for epoch");

        _contributionScoresTotalForEpoch[epoch].validation_score    = validation_score_for_epoch;
        _contributionScoresTotalForEpoch[epoch].metadata_score      = metadata_score_for_epoch;

        emit TotalScoresUpdated(epoch, validation_score_for_epoch, metadata_score_for_epoch);
    }
}