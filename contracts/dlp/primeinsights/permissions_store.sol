// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

abstract contract PermissionsStore
{
    address internal _superadminAddress = address(0);

    mapping(address user => uint8 group) 
        internal _userGroup;

    mapping(uint8 group => uint128 permissions) 
        internal _groupPermissions;

    mapping(uint8 group => uint8 rank) 
        internal _groupRank;
}
