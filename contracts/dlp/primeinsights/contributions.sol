// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Common }               from "./common.sol";
import { ContributionsStore }   from "./contributions_store.sol";
import { DataRegistry }         from "./data_reg.sol";
import { IDataRegistry }        from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { RewardsStore }         from "./rewards_store.sol";

uint128 constant PERMISSION_REMOVE_CONTRIBUTION = 0x1000;

abstract contract Contributions is Common, ContributionsStore, DataRegistry, RewardsStore
{
    function getNumContributors() public view returns (uint256)
    {
        return _contributors.length;
    }

    function getNumContributions() public view returns (uint256)
    {
        return _contributions.length;
    }

    function getNumContributionsByOwner(
        address owner
    ) public view returns (uint256)
    {
        return _contributionsByOwner[owner].length;
    }

    event ContributionAdded(uint64 indexed epoch, address indexed owner, uint256 contribution);
    function addContribution(
        address owner,
        uint256 contribution
    ) internal
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

     function addContributionWithPermissions(
        string memory                       url,
        address                             owner_address,
        IDataRegistry.Permission[] memory   permissions
    ) public
    {
        uint256 contribution = dr_addFileWithPermissions(url, owner_address, permissions);
        addContribution(owner_address, contribution);

        //return dr_addFileWithPermissions(url, ownerAddress, permissions);
    }

    event ContributionRemoved(uint64 indexed epoch, address indexed owner, uint256 contribution);
    function _removeContribution(
        uint256 contribution
    ) internal
    {
        // find previous last contribution if they have more than one contribution
        address owner = _contributionOwner[contribution];
        if (_lastContribution[owner][_lastContributionEpoch[owner]] == contribution 
            && getNumContributionsByOwner(owner) > 1
        )
        {
            uint64 epoch = _lastContributionEpoch[owner];
            while (epoch > 0 && _lastContribution[owner][epoch - 1] == 0)
            {
                epoch--;
            }

            _lastContribution[owner][epoch] = contribution;
            _lastContributionEpoch[owner]   = epoch;
        }

        uint256 num_contributions = getNumContributions();
        for (uint256 i = 0; i < num_contributions; i++)
        {
            if (_contributions[i] == contribution)
            {
                _contributions[i] = _contributions[num_contributions - 1];
                _contributions.pop();

                break;
            }
        }

        uint256 num_contributions_by_owner = getNumContributionsByOwner(owner);
        for (uint256 i = 0; i < num_contributions_by_owner; i++)
        {
            if (_contributionsByOwner[owner][i] == contribution)
            {
                _contributionsByOwner[owner][i] = _contributionsByOwner[owner][num_contributions_by_owner - 1];  // copy last element to current position
                _contributionsByOwner[owner].pop();                                                             // remove last element

                break;
            }
        }

        delete _contributionOwner[contribution];

        emit ContributionRemoved(getCurrentEpoch(), owner, contribution);
    }

    function removeContribution(
        uint256 contribution
    ) external
    {
        require(msg.sender != address(0), "Invalid sender");
        require(contribution != 0, "Invalid contribution");
        
        // if not admin only allow removal of contributions by sender
        if (!checkPermissionForUser(msg.sender, PERMISSION_REMOVE_CONTRIBUTION))
        {
            require(_contributionOwner[contribution] == msg.sender, "Not the owner of the contribution");
            require(_lastClaimedEpoch[msg.sender] == getCurrentEpoch() - 1, "Cannot remove contribution while there are unclaimed rewards");
        }

        _removeContribution(contribution);
    }
}