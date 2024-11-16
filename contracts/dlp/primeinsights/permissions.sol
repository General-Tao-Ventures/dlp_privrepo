// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

uint128 constant    PERMISSION_EDIT_ROLES          = 1;
uint128 constant    PERMISSION_EDIT_PERMISSIONS    = 2;

uint8 constant      GROUP_SUPERADMIN    = 0;
uint8 constant      GROUP_ADMIN         = 1;
uint8 constant      GROUP_USER          = 2;

import { IPermissions }     from "./interfaces/ipermissions.sol";
import { PermissionsStore } from "./permissions_store.sol";
abstract contract Permissions is IPermissions, PermissionsStore
{
    modifier onlySuperadmin()
    {
        require(msg.sender == getSuperadminAddress(), "Not authorized");

        _;
    }

    modifier requireHigherRankedGroup(
        address user,
        uint8 group
    )
    {
        if (user != getSuperadminAddress())
        {
            require(group < getUserGroup(user), "Not authorized");
        }

        _;
    }

    modifier requireHigherRank(
        address user,
        uint8 rank
    )
    {
        if (user != getSuperadminAddress())
        {
            require(rank < getGroupRank(getUserGroup(user)), "Not authorized");
        }

        _;
    }

    modifier permissionedCall(
        address caller,
        uint128 permissions
    )
    {
        require(caller == getSuperadminAddress() || checkPermission(caller, permissions), "Not authorized");

        _;
    }

    modifier permissionedCallHigherRankedGroup(
        address caller,
        uint8 group,
        uint128 permissions
    )
    {
        if(caller != getSuperadminAddress())
        {
            require(checkPermission(caller, permissions), "Not authorized");
            require(isHigherRankedGroup(getUserGroup(caller), group), "Not authorized");
        }

        _;
    }

    function getSuperadminAddress() public view returns (address)
    {
        return _superadminAddress;
    }

    function setSuperadminAddress(
        address new_superadmin_address
    ) public onlySuperadmin()
    {
        _superadminAddress = new_superadmin_address;
    }

    function isSuperadmin(
        address user
    ) public view returns (bool)
    {
        return getSuperadminAddress() == user;
    }

    function getUserGroup(
        address user
    ) public view returns (uint8)
    {
        return _userGroup[user];
    }

    function getPermissions(
        address user
    ) public view returns (uint128)
    {
        return _groupPermissions[getUserGroup(user)];
    }

    function checkPermission(
        address user,
        uint128 permissions
    ) public view returns (bool)
    {
        return (getPermissions(user) & permissions) == permissions;
    }

    function getGroupRank(
        uint8 group
    ) public view returns (uint8)
    {
        return _groupRank[group];
    }

    function setGroupRank(
        uint8 group,
        uint8 rank
    ) public permissionedCallHigherRankedGroup(msg.sender, group, PERMISSION_EDIT_ROLES) requireHigherRank(msg.sender, rank)
    {
        require(group != GROUP_SUPERADMIN, "Superadmin group rank cannot be changed");

        _groupRank[group] = rank;
    }

    function isHigherRankedGroup(
        uint8 group1,
        uint8 group2
    ) public view returns (bool)
    {
        return getGroupRank(group1) > getGroupRank(group2);
    }

    function addPermissions(
        address user,
        uint128 permissions
    ) public permissionedCallHigherRankedGroup(msg.sender, getUserGroup(user), PERMISSION_EDIT_PERMISSIONS)
    {
        _groupPermissions[_userGroup[user]] |= permissions;
    }

    function removePermissions(
        address user,
        uint128 permissions
    ) public permissionedCallHigherRankedGroup(msg.sender, getUserGroup(user), PERMISSION_EDIT_PERMISSIONS)
    {
        _groupPermissions[_userGroup[user]] &= ~permissions;
    }
}
