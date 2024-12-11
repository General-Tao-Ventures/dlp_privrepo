// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { IDataRegistry }    from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { Permissions }      from "./permissions.sol";

uint128 constant PERMISSION_UPDATE_DATA_REGISTRY = 0x200;

abstract contract DataRegistry is Permissions
{
    function updateDataRegistry(
        address new_data_registry
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_DATA_REGISTRY)
    {
        _dataRegistry = IDataRegistry(new_data_registry);
    }

    function dr_getMetadata(
        uint256 contribution, 
        uint256 index
    ) internal view returns (string memory)
    {
        return _dataRegistry.fileProofs(contribution, index).data.metadata;
    }

    function dr_addFile(
        string memory url
    ) internal returns (uint256)
    {
        return _dataRegistry.addFile(url);
    }

    function dr_addFileWithPermissions(
        string memory url,
        address owner_address,
        IDataRegistry.Permission[] memory permissions
    ) internal returns (uint256)
    {
        return _dataRegistry.addFileWithPermissions(url, owner_address, permissions);   
    }
}
