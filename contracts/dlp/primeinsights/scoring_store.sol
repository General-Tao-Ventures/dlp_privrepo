// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract ScoringStore
{
    struct Category 
    {
        string  name;
        bool    disabled;
    }

    struct ContributionScore
    {
        uint64 validation_score;
        uint64 metadata_score;
    }

    Category[] internal _categories;

    uint16 internal _validationWeight = 40;
    uint16 internal _metadataWeight   = 60;

    mapping(uint256 contribution => uint64 last_updated_epoch)
                                                internal _contributionScoresUpdatedEpoch;

    mapping(uint64 epoch => ContributionScore score)
                                                internal _contributionScoresTotalForEpoch;

    mapping(uint256 contribution => mapping(
                        uint64 epoch => mapping(
                        uint16 category => ContributionScore score)))
                                                internal _contributionScores;
}