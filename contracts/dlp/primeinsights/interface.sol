// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { Permissions }      from "./permissions.sol";
import { Rewards }          from "./rewards.sol";
import { Contributions }    from "./contributions.sol";
import { Common }           from "./common.sol";
import { IDataRegistry }    from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { StorageV2 }        from "./storagev2.sol";
import { ITeePool }        from "../../dependencies/teePool/interfaces/ITeePool.sol";

uint128 constant PERMISSION_PAUSE           = 0x100;

// all things from IDataLiquidityPool
abstract contract DLPInterface is StorageV2, Permissions, Common, Contributions, Rewards
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

    function ownerRewardFactor() external view returns (uint256)
    {
        return _ownerRewardFactor;
    }

    function currentEpoch() external view returns (uint64)
    {
        return _currentEpoch;
    }

    function rewardSender() external view returns (address)
    {
        return _rewardSender;
    }

    function rewardSenderFinalizesEpoch() external view returns (bool)
    {
        return _rewardSenderFinalizesEpoch;
    }

    function teePool() external view returns (ITeePool)
    {
        return _teePool;
    }

    function maxClaimableEpoch() external view returns (uint64)
    {
        return _maxClaimableEpoch;
    }

    function filesListCount() external view returns (uint256)
    {
        return _contributions.length;
    }

    function contributorsCount() external view returns (uint256)
    {
        return _contributors.length;
    }

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

    function addFileWithPermissions(
        string memory                       url,
        address                             owner_address,
        IDataRegistry.Permission[] memory   permissions
    ) external
    {
        return addContributionWithPermissions(url, owner_address, permissions);
    }

    // function updateScoreAndOwnerRewardsForContributor
    // (
    //     uint256 contributor, 
    //     uint64 epoch
    // ) external
    // {
    //     require(contributor < getNumContributors());
    //     require(epoch <= _currentEpoch);

    //     updateScoreForContributior(contributor, epoch);

    //     uint64 first_epoch_to_claim = findFirstEpochToClaim(_contributors[contributor]);
    //     uint64 epoch_to_recycle = _firstEpochToRecycleForContributor[contributor];
    //     if (epoch_to_recycle < first_epoch_to_claim)
    //     {
    //         epoch_to_recycle = first_epoch_to_claim;
    //     }

    //     while(epoch_to_recycle < epoch - _maxClaimableEpoch)
    //     {
    //         recycleUnclaimedRewardsForContributor(contributor, epoch_to_recycle);
    //         epoch_to_recycle ++;
    //     }
    //     _firstEpochToRecycleForContributor[contributor] = epoch_to_recycle;
    // }
}
