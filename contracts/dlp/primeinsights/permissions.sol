// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

uint128 constant    PERMISSION_EDIT_ROLES          = 0x1;
uint128 constant    PERMISSION_SET_ROLE            = 0x2;
uint128 constant    PERMISSION_EDIT_PERMISSIONS    = 0x4;

uint8 constant      GROUP_SUPERADMIN    = 0;

import { PermissionsStore } from "./permissions_store.sol";
abstract contract Permissions is PermissionsStore
{
    modifier onlySuperadmin()
    {
        require(isSuperadmin(msg.sender), "User is not the superadmin");

        _;
    }

    modifier requireHigherRankedGroup(
        address user,
        uint8 group
    )
    {
        if (!isSuperadmin(user))
        {
            require(isHigherRankedGroup(getUserGroup(user), group), "User is not in a higher ranked group");
        }

        _;
    }

    modifier requireHigherRank(
        address user,
        uint8 rank
    )
    {
        if (!isSuperadmin(user))
        {
            require(getGroupRank(getUserGroup(user)) > rank, "User is not in a higher rank");
        }

        _;
    }

    modifier permissionedCall(
        address user,
        uint128 permissions
    )
    {
        require(checkPermissionForUser(user, permissions), "User does not have permission");

        _;
    }

    modifier permissionedCallHigherRankedGroup(
        address user,
        uint8 group,
        uint128 permissions
    )
    {
        if(!isSuperadmin(user))
        {
            require(checkPermissionForUser(user, permissions), "User does not have permission");
            require(isHigherRankedGroup(getUserGroup(user), group), "User is not in a higher ranked group");
        }

        _;
    }

    function getSuperadminAddress() public view returns (address)
    {
        return _superadminAddress;
    }

    event SuperadminAddressSet(address indexed new_superadmin_address);
    function setSuperadminAddress(
        address new_superadmin_address
    ) public onlySuperadmin()
    {
        _superadminAddress = new_superadmin_address;

        emit SuperadminAddressSet(new_superadmin_address);
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
        return isSuperadmin(user) ? GROUP_SUPERADMIN : _userGroup[user];
    }

    event UserGroupSet(address indexed user, uint8 indexed group);
    function setUserGroup(
        address user,
        uint8 group
    ) public permissionedCallHigherRankedGroup(msg.sender, group, PERMISSION_EDIT_ROLES)
    {
        _userGroup[user] = group;

        emit UserGroupSet(user, group);
    }

    function getGroupRank(
        uint8 group
    ) public view returns (uint8)
    {
        return group == GROUP_SUPERADMIN ? 0 : _groupRank[group];
    }

    event GroupRankSet(uint8 indexed group, uint8 indexed rank);    
    function setGroupRank(
        uint8 group,
        uint8 rank
    ) public requireHigherRank(msg.sender, rank) permissionedCallHigherRankedGroup(msg.sender, group, PERMISSION_EDIT_ROLES)
    {
        require(group != GROUP_SUPERADMIN, "Superadmin rank cannot be changed");

        _groupRank[group] = rank;
        emit GroupRankSet(group, rank);
    }

    function isHigherRankedGroup(
        uint8 group1,
        uint8 group2
    ) public view returns (bool)
    {
        return getGroupRank(group1) > getGroupRank(group2);
    }

    function getPermissionsForUser(
        address user
    ) public view returns (uint128)
    {
        return isSuperadmin(user) 
            ? 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF 
            : _groupPermissions[getUserGroup(user)];
    }

    function checkPermissionForUser(
        address user,
        uint128 permissions
    ) public view returns (bool)
    {
        return (getPermissionsForUser(user) & permissions) == permissions;
    }
    
    event PermissionsAdded(uint8 indexed group, uint128 indexed permissions);
    function addPermissions(
        uint8 group,
        uint128 permissions
    ) public permissionedCallHigherRankedGroup(msg.sender, group, permissions | PERMISSION_EDIT_PERMISSIONS) 
    {
        require(group != GROUP_SUPERADMIN, "Superadmin perms cannot be changed");

        _groupPermissions[group] |= permissions;
        emit PermissionsAdded(group, permissions);
    }

    event PermissionsRemoved(uint8 indexed group, uint128 indexed permissions);
    function removePermissions(
        uint8 group,
        uint128 permissions
    ) public permissionedCallHigherRankedGroup(msg.sender, group, permissions | PERMISSION_EDIT_PERMISSIONS)
    {
        require(group != GROUP_SUPERADMIN, "Superadmin perms cannot be changed");

        _groupPermissions[group] &= ~permissions;
        emit PermissionsRemoved(group, permissions);
    }

    event RoleSet(address indexed user, uint8 indexed group);
    function setRole(
        address user,
        uint8 group
    ) public requireHigherRank(msg.sender, getUserGroup(user)) permissionedCallHigherRankedGroup(msg.sender, group, PERMISSION_SET_ROLE)
    {
        _userGroup[user] = group;

        emit RoleSet(user, group);
    }
}
 