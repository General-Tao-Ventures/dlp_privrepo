// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { Permissions }      from "./permissions.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { IERC20 }           from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 }        from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
abstract contract DLPInterface is Permissions, Contributions, Rewards
{
    using SafeERC20 for IERC20;

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

    //function contributorsCount() external view returns (uint256)
    //{
    //    return _contributionsByOwner.length;
    //}

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

    //function pause()
    //{
    //}

    //function unpause()
    //{
    //}

    //function updateFileRewardFactor(uint256 newFileRewardFactor) external
    //{
    //    fileRewardFactor = newFileRewardFactor;
    //}

    //function updateTeePool(address newTeePool) external
    //{
    //}

    //function updateProofInstruction(string calldata newProofInstruction) external
    //{
    //}

    //function updatePublicKey(string calldata newProofInstruction) external
    //{
    //}

    function requestReward(uint256 registryFileId, uint256 proofIndex) external
    {
        // we dont do per-file claining, we claim all at once
        claimRewards();
    }

    function addRewardsForContributors(uint256 contributorsRewardAmount) external
    {
        //IERC20(token)
        //    .safeTransferFrom(msg.sender, address(this), contributorsRewardAmount);

        //addRewardForCurrentEpoch(token, contributorsRewardAmount);
    }
}
