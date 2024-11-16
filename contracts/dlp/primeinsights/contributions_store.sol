// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract ContributionsStore
{
    uint256[]   internal _contributions;

    mapping(uint256 contribution => address owner) 
                                                internal _contributionOwner;

    mapping(address owner => uint256[] contributions) 
                                                internal _contributionsByOwner;
}