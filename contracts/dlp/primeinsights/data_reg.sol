// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { IDataRegistry }    from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { Permissions }      from "./permissions.sol";
import { Common }           from "./common.sol";
import { StorageV2 }        from "./storagev2.sol";

uint128 constant PERMISSION_UPDATE = 0x2000;

abstract contract DataRegistry is StorageV2, Permissions, Common
{
    event DataRegistryUpdated(uint64 indexed epoch, address new_data_registry);
    function updateDataRegistry(
        address new_data_registry
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        _dataRegistry = IDataRegistry(new_data_registry);

        emit DataRegistryUpdated(_currentEpoch, new_data_registry);
    }

    function dr_getMetadata(
        uint256 contribution, 
        uint256 index
    ) internal view returns (string memory)
    {
        return _dataRegistry.fileProofs(contribution, index).data.metadata;
    }

    function dr_addFileWithPermissions(
        string memory url,
        address owner_address,
        IDataRegistry.Permission[] memory permissions
    ) internal returns (uint256)
    {
        return _dataRegistry.addFileWithPermissions(url, owner_address, permissions);   
    }

    function dr_getProof(
        uint256 contribution,
        uint256 index
    ) internal view returns (IDataRegistry.Proof memory)
    {
        return _dataRegistry.fileProofs(contribution, index);
    }

    function dr_getFileUrl(
        uint256 contribution
    ) internal view returns (string memory)
    {
        return _dataRegistry.files(contribution).url;
    }
}
