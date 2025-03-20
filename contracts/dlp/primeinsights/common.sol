// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { StorageV2 }        from "./storagev2.sol";
import { Permissions }      from "./permissions.sol";

uint128 constant PERMISSION_UPDATE                    = 0x2000;

abstract contract Common is StorageV2, Permissions
{
    event EpochAdvanced(uint64 indexed epoch);
    function advanceEpoch() internal
    {
        _currentEpoch++;

        emit EpochAdvanced(_currentEpoch);
    }

    function isPaused() public view returns (bool)
    {
        return _paused != 0x0;
    }

    function setRewardSender(
        address new_reward_sender
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        _rewardSender = new_reward_sender;
    }

    function setName(
        string memory new_name
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        _name = new_name;
    }

    function setPublicKey(
        string memory new_public_key
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        _publicKey = new_public_key;
    }

    event ProofInstructionUpdated(uint64 indexed epoch, string new_proof_instruction);
    function setProofInstruction(
        string memory new_proof_instruction
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        _proofInstruction = new_proof_instruction;

        emit ProofInstructionUpdated(_currentEpoch, new_proof_instruction);
    }

    event OwnerRewardFactorUpdated(uint64 indexed epoch, uint256 new_owner_reward_factor);
    function setOwnerRewardFactor(
        uint256 new_owner_reward_factor
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        require(new_owner_reward_factor <= 100);
        _ownerRewardFactor = new_owner_reward_factor;

        emit OwnerRewardFactorUpdated(_currentEpoch, new_owner_reward_factor);
    }

    event RewardSenderFinalizesEpochUpdated(uint64 indexed epoch, bool new_reward_sender_finalizes_epoch);
    function setRewardSenderFinalizesEpoch(
        bool new_reward_sender_finalizes_epoch
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        _rewardSenderFinalizesEpoch = new_reward_sender_finalizes_epoch;

        emit RewardSenderFinalizesEpochUpdated(_currentEpoch, new_reward_sender_finalizes_epoch);
    }

    event MaxClaimableEpochUpdated(uint64 indexed epoch, uint64 new_max_claimable_epoch);
    function setMaxClaimableEpoch(
        uint64 new_max_claimable_epoch
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE)
    {
        require(new_max_claimable_epoch > 0);
        _maxClaimableEpoch = new_max_claimable_epoch;

        emit MaxClaimableEpochUpdated(_currentEpoch, new_max_claimable_epoch);
    }
}
