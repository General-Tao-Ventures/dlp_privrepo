// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Permissions }      from "./permissions.sol";
import { Contributions }    from "./contributions.sol";
abstract contract RewardsStoreV1 is Common, Permissions, Contributions
{
    //category data
    struct Category 
    {
        uint8[] scoring_weights;
        bool    disabled;
    }

    struct ContributionScore
    {
        uint64 validation_score;
        uint64 metadata_score;
    }

    address[]   internal _tokens;
    Category[]  internal _categories;

    uint64 internal _validationWeight = 40;
    uint64 internal _metadataWeight   = 60;

    mapping(uint256 contribution => uint64 last_updated_epoch)
                                                internal _contributionScoresUpdatedEpoch;

    mapping(uint256 contribution => uint8[][] metadata_scores)
                                                internal _contributionMetadataScores;

    mapping(uint256 contribution => uint8[][] validation_scores)
                                                internal _contributionValidationScores;

    mapping(uint64 epoch => ContributionScore score)
                                                internal _contributionScoresTotalForEpoch;

    mapping(uint256 contribution => mapping(
                        uint64 epoch => mapping(
                        uint16 category => ContributionScore score)))
                                                internal _contributionScores;
    
    // rewards
    mapping(address owner => uint64 first_updated_epoch)
                                                internal _firstDistributionEpoch;

    mapping(uint64 epoch => mapping(
                        address token => uint256 reward))
                                                internal _rewardsForEpoch;
    
    mapping(address addr => uint64 last_claimed_epoch) 
                                                internal _lastClaimedEpoch;
}