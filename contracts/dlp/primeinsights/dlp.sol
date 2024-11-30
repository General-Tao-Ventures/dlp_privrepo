// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { Permissions }      from "./permissions.sol";
import { DLPInterface }     from "./interface.sol";

uint128 constant PERMISSION_FINISH_EPOCH = 0x400;

abstract contract DLP is Permissions, Common, Contributions, Rewards, DLPInterface
{
    function finishEpoch() external permissionedCall(msg.sender, PERMISSION_FINISH_EPOCH)
    {
        require(!_paused, "Contract is paused");
        updateScoresForContributionsAtEpoch(getCurrentEpoch());

        advanceEpoch();
    }
}
