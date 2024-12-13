// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { Permissions }      from "./permissions.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { Common }           from "./common.sol";
import { TEEPool }          from "./tee.sol";
import { IDataRegistry }    from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { ITeePool }         from "../../dependencies/teePool/interfaces/ITeePool.sol";

uint128 constant PERMISSION_PAUSE           = 0x100;

// all things from IDataLiquidityPool
abstract contract DLPInterface is Permissions, Common, Contributions, Rewards, TEEPool
{
    /*
    function version() external pure returns (uint256);
    function token() external view returns (IERC20);
    function totalContributorsRewardAmount() external view returns (uint256);
    */

    function name() external view returns (string memory)
    {
        return _name;
    }

    function publicKey() external view returns (string memory)
    {
        return _publicKey;
    }

    function proofInstruction() external view returns (string memory)
    {
        return _proofInstruction;
    }

    function fileRewardFactor() external view returns (uint256)
    {
        return _fileRewardFactor;
    }

    function filesListCount() external view returns (uint256)
    {
        return _contributions.length;
    }

    function filesListAt(uint256 index) external view returns (uint256)
    {
        if(_contributionOwner[index] == address(0))
        {
            return 0;
        }

        return 1;
    }

    //function files(uint256 fileId) external view returns (FileResponse memory)
    //{
        //return _files[fileId];
    //}

    function contributorsCount() external view returns (uint256)
    {
        return _contributors.length;
    }

    //function contributors(uint256 index) external view override returns (ContributorInfoResponse memory) 
    //{
    //    return contributorInfo(_contributors[index]);
    //}

    //function contributorInfo(address contributorAddress) external view returns (ContributorInfoResponse memory)
    //{
    //    return _contributorInfo[contributorAddress];
    //}

    function contributorFiles(address contributorAddress, uint256 index) external view returns (uint256)
    {
        return _contributionsByOwner[contributorAddress][index];
    }

    function pause() external permissionedCall(msg.sender, PERMISSION_PAUSE)
    {
        _paused = 0xFFFFFFFFFFFFFFFF;
    }

    function unpause() external permissionedCall(msg.sender, PERMISSION_PAUSE)
    {
        _paused = 0x0;
    }

    function requestReward(uint256 registry_file_id, uint256 proof_idx) external
    {
        // we dont do per-file claiming, we claim all at once
        claimRewards();
    }

    function addFileWithPermissions(
        string memory                       url,
        address                             owner_address,
        IDataRegistry.Permission[] memory   permissions
    ) external
    {
        return addContributionWithPermissions(url, owner_address, permissions);
    }
}
