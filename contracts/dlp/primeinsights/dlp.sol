// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }           from "./common.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { Permissions }      from "./permissions.sol";

abstract contract DLP is Common, Permissions, Contributions, Rewards
{
    function finishEpoch() internal
    {
        updateScoresForContributionsAtEpoch(getCurrentEpoch());

        advanceEpoch();
    }
}
