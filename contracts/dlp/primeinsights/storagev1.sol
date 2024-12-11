// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { IDataRegistry }    from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";

abstract contract StorageV1
{
    //common
    uint64  internal _currentEpoch;
    uint64  internal _paused;
    address internal _rewardSender;
    bool    internal _rewardSenderFinalizesEpoch;
    string  internal _name;
    string  internal _publicKey;
    string  internal _proofInstruction;
    uint256 internal _fileRewardFactor;
    //contributions
    uint256[]   internal _contributions;
    address[]   internal _contributors;

    mapping(uint256 contribution => address owner) 
                                                internal _contributionOwner;

    mapping(address owner => uint256[] contributions) 
                                                internal _contributionsByOwner;

    mapping(uint256 contribution => uint64 epoch) 
                                                internal _contributionEpoch;

    mapping(address owner => mapping(
                        uint64 epoch => uint256 contribution))  
                                                internal _lastContribution;

    mapping(address owner => uint64 epoch) 
                                                internal _lastContributionEpoch;
    //permissions
    address internal _superadminAddress = address(0);

    mapping(address user => uint8 group) 
                                    internal _userGroup;

    mapping(uint8 group => uint128 permissions) 
                                    internal _groupPermissions;

    mapping(uint8 group => uint8 rank) 
                                    internal _groupRank;
    //rewards
    address[]   internal _rewardTokens;
    uint64      internal _dlpOwnerLastClaimedEpoch;

    mapping(address owner => uint64 first_updated_epoch)
                                                internal _firstDistributionEpoch;

    mapping(uint64 epoch => mapping(
                        address token => uint256 reward))
                                                internal _rewardsForEpoch;

    mapping(uint64 epoch => mapping(
                        address token => uint256 reward))
                                                internal _dlpOwnerRewardsForEpoch;
    
    mapping(address addr => uint64 last_claimed_epoch) 
                                                internal _lastClaimedEpoch;
    //scoring
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

    struct ContributionScoreTotal
    {
        uint256 validation_score;
        uint256 metadata_score;
    }

    Category[] internal _categories;

    uint16 internal _validationWeight = 40;
    uint16 internal _metadataWeight   = 60;

    mapping(uint256 contribution => uint64 last_updated_epoch)
                                                internal _contributionScoresUpdatedEpoch;

    mapping(uint64 epoch => ContributionScoreTotal score)
                                                internal _contributionScoresTotalForEpoch;

    mapping(uint256 contribution => mapping(
                        uint64 epoch => mapping(
                        uint16 category => ContributionScore score)))
                                                internal _contributionScores;

    //data reg
    IDataRegistry internal _dataRegistry;
    //gap
    uint256[50] private __gap;
}