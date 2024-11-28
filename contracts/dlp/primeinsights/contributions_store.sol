// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract ContributionsStore
{
    uint256[]   internal _contributions;
    address[]   internal _contributors;

    mapping(uint256 contribution => address owner) 
                                                internal _contributionOwner;

    mapping(address owner => uint256[] contributions) 
                                                internal _contributionsByOwner;

    mapping(uint256 contribution => uint64 epoch) 
                                                internal _contributionEpoch;

    mapping(address owner => mapping(uint64 epoch => uint256 contribution))  
                                                internal _lastContribution;

    mapping(address owner => uint64 epoch) 
                                                internal _lastContributionEpoch;
}
