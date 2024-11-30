// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Permissions }      from "./permissions.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { IERC20 }           from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 }        from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITeePool }         from "../../dependencies/teePool/interfaces/ITeePool.sol";

uint128 constant PERMISSION_UPDATE_TEE_POOL = 0x80;
uint128 constant PERMISSION_PAUSE           = 0x100;

abstract contract DLPInterface is Permissions, Contributions, Rewards
{
    using SafeERC20 for IERC20;
    ITeePool    internal _teePool;
    address     internal _nativeRewardToken;

    /*
    function name() external view returns (string memory);
    function version() external pure returns (uint256);
    function dataRegistry() external view returns (IDataRegistry);
    function teePool() external view returns (ITeePool);
    function token() external view returns (IERC20);
    function publicKey() external view returns (string memory);
    function proofInstruction() external view returns (string memory);
    function totalContributorsRewardAmount() external view returns (uint256);
    function fileRewardFactor() external view returns (uint256);
    */

    function filesListCount() external view returns (uint256)
    {
        return _contributions.length;
    }

    //function filesListAt(uint256 index) external view returns (uint256)
    //{
    //    return _contributions[index];
    //}

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
        _paused = true;
    }

    function unpause() external permissionedCall(msg.sender, PERMISSION_PAUSE)
    {
        _paused = false;
    }

    //function updateFileRewardFactor(uint256 newFileRewardFactor) external
    //{
    //    fileRewardFactor = newFileRewardFactor;
    //}

    function updateTeePool(
        address new_tee
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_TEE_POOL)
    {
        _teePool = ITeePool(new_tee);
    }

    //function updateProofInstruction(string calldata newProofInstruction) external
    //{
    //}

    //function updatePublicKey(string calldata newProofInstruction) external
    //{
    //}

    function requestReward(uint256 registry_file_id, uint256 proof_idx) external
    {
        // we dont do per-file claiming, we claim all at once
        claimRewards();
    }

    function addRewardsForContributors(uint256 reward_amount) external
    {
        return receiveToken(_nativeRewardToken, reward_amount);
    }
}
