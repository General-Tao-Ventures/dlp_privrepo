// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { Common }               from "./common.sol";
import { DataRegistry }         from "./data_reg.sol";
import { IDataRegistry }        from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { StorageV2 }           from "./storagev2.sol";

uint128 constant PERMISSION_REMOVE_CONTRIBUTION = 0x1000;

abstract contract Contributions is StorageV2, Common, DataRegistry
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
        require(_paused == 0x0); // Contract paused
        require(contribution != 0);
        require(owner != address(0));
        require(_contributionOwner[contribution] == address(0)); // Contribution exists

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

    function removeLastContribution(
        address owner
    ) external
    {
        // if not admin, only allow removal of last contribution by sender
        if (!checkPermissionForUser(msg.sender, PERMISSION_REMOVE_CONTRIBUTION))
        {
            require(owner == msg.sender); // Not owner
        }

        _removeLastContribution(owner);
    }

    event ContributionRemoved(uint64 indexed epoch, address indexed owner, uint256 contribution);
    function _removeLastContribution(
        address owner
    ) internal
    {
        uint256 num_contributions = getNumContributionsByOwner(owner);
        require(num_contributions > 0); // Owner has contributions

        uint256 last_contribution = _contributionsByOwner[owner][num_contributions - 1];
        
        // remove last_contribution from _contributionsByOwner
        _contributionsByOwner[owner].pop();

        // remove last_contribution from _contributions
        uint256 num_total_contributions = getNumContributions();
        for (uint256 i = 0; i < num_total_contributions; i++)
        {
            if (_contributions[i] == last_contribution)
            {
                _contributions[i] = _contributions[num_total_contributions - 1];
                _contributions.pop();

                break;
            }
        }
        
        // keep _lastContributionEpoch as it is
        uint64 epoch = _lastContributionEpoch[owner];
        _lastContributionEpoch[owner] = epoch;

        // update _lastContribution to the second last contribution
        if (num_contributions > 1)
        {
            _lastContribution[owner][epoch] = _contributionsByOwner[owner][num_contributions - 2];
        }
        else
        {
            // no contributions left for this owner
            // remove owner from _contributors
            uint256 num_contributors = getNumContributors();
            for (uint256 i = 0; i < num_contributors; i++)
            {
                if (_contributors[i] == owner)
                {
                    _contributors[i] = _contributors[num_contributors - 1];
                    _contributors.pop();

                    break;
                }
            }
            
            delete _lastContribution[owner][epoch];
            delete _lastContributionEpoch[owner];
        }

        delete _contributionOwner[last_contribution];

        emit ContributionRemoved(getCurrentEpoch(), owner, last_contribution);
    }
}