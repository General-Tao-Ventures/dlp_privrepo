// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { ITeePool }         from "../../dependencies/teePool/interfaces/ITeePool.sol";
import { Permissions }      from "./permissions.sol";

uint128 constant PERMISSION_UPDATE_TEE_POOL = 0x80;

abstract contract TEEPool is Permissions
{
    ITeePool    internal _teePool;

    event TeePoolUpdated(address indexed new_tee_pool);
    function updateTeePool(
        address new_tee
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_TEE_POOL)
    {
        _teePool = ITeePool(new_tee);

        emit TeePoolUpdated(new_tee);
    }
}
