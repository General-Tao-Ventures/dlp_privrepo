// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract CommonDataStore
{
    uint64  internal _currentEpoch;
    uint64  internal _paused;
    address internal _rewardSender;
    bool    internal _rewardSenderFinalizesEpoch;
    string  internal _name;
    string  internal _publicKey;
    string  internal _proofInstruction;
    uint256 internal _fileRewardFactor;
}
