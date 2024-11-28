// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IDataRegistry} from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
abstract contract DataRegistry 
{
    IDataRegistry public dataRegistry;

    //constructor(address dataRegistryAddress) 
    //{
    //    dataRegistry = IDataRegistry(dataRegistryAddress);
    //}

    function dr_getMetadata(
        uint256 contribution, 
        uint256 index
    ) internal view returns (string memory)
    {
        return dataRegistry.fileProofs(contribution, index).data.metadata;
    }
}
