// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }               from "./common.sol";
import { ContributionsStore }   from "./contributions_store.sol";

uint128 constant PERMISSION_ADD_CONTRIBUTION = 0x1000;

abstract contract Contributions is Common, ContributionsStore
{
    function getNumContributors() public view returns (uint64)
    {
        return uint64(_contributors.length);
    }

    function getNumContributions() public view returns (uint64)
    {
        return uint64(_contributions.length);
    }

    function getNumContributionsByOwner(
        address owner
    ) public view returns (uint64)
    {
        return uint64(_contributionsByOwner[owner].length);
    }

    event ContributionAdded(uint64 indexed epoch, address indexed owner, uint256 contribution);
    function addContribution(
        address owner,
        uint256 contribution
    ) external permissionedCall(msg.sender, PERMISSION_ADD_CONTRIBUTION)
    {
        require(!_paused, "Contract is paused");
        require(contribution != 0, "Invalid contribution");
        require(owner != address(0), "Invalid owner");
        require(_contributionOwner[contribution] == address(0), "Contribution already added");

        _contributions.push(contribution);

        if (_contributionsByOwner[owner].length == 0) // this is the first contribution for this owner
        {
            _contributors.push(owner);
        }
        _contributionsByOwner[owner].push(contribution);

        _contributionOwner[contribution] = owner;

        uint64 epoch                    = getCurrentEpoch();
        _lastContribution[owner][epoch] = contribution;
        _lastContributionEpoch[owner]   = epoch;

        emit ContributionAdded(epoch, owner, contribution);
    }

    // might need to track indices in a mapping to make this more efficient
    /*function removeContribution(
        uint256 contribution
    ) internal
    {
        address owner = _contributionOwner[contribution];
        require(owner != address(0), "Invalid owner");

        uint64 num_contributions = getNumContributions();
        for (uint64 i = 0; i < num_contributions; i++)
        {
            if (_contributions[i] == contribution)
            {
                _contributions[i] = _contributions[num_contributions - 1];
                _contributions.pop();

                break;
            }
        }

        num_contributions = getNumContributionsByOwner(owner);
        for (uint64 i = 0; i < num_contributions; i++)
        {
            if (_contributionsByOwner[owner][i] == contribution)
            {
                _contributionsByOwner[owner][i] = _contributionsByOwner[owner][num_contributions - 1];  // copy last element to current position
                _contributionsByOwner[owner].pop();                                                     // remove last element

                break;
            }
        }

        delete _contributionOwner[contribution];
    }*/
}