// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract RewardsStore
{
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
}