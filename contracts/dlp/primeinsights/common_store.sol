// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

abstract contract CommonDataStore
{
    uint64  internal _currentEpoch;
    bool    internal _paused;
}