// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { Permissions }      from "./permissions.sol";
import { DLPInterface }     from "./interface.sol";

abstract contract DLP is Permissions, Common, Contributions, Rewards, DLPInterface
{
    function finishEpoch() internal
    {
        require(!_paused, "Contract is paused");
        updateScoresForContributionsAtEpoch(getCurrentEpoch());

        advanceEpoch();
    }
}
