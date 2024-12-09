// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { CommonDataStore }  from "./common_store.sol";
import { Permissions }      from "./permissions.sol";

uint128 constant PERMISSION_UPDATE_REWARD_SENDER        = 0x2000;
uint128 constant PERMISSION_UPDATE_NAME                 = 0x4000;
uint128 constant PERMISSION_UPDATE_PUBLIC_KEY           = 0x8000;
uint128 constant PERMISSION_UPDATE_PROOF_INSTRUCTION    = 0x10000;
uint128 constant PERMISSION_UPDATE_FILE_REWARD_FACTOR   = 0x20000;

abstract contract Common is CommonDataStore, Permissions
{
    address internal _rewardSender;
    string  internal _name;
    string  internal _publicKey;
    string  internal _proofInstruction;
    uint256 internal _fileRewardFactor;

    function getCurrentEpoch() public view returns (uint64)
    {
        return _currentEpoch;
    }

    event EpochAdvanced(uint64 indexed epoch);
    function advanceEpoch() internal
    {
        _currentEpoch++;

        emit EpochAdvanced(_currentEpoch);
    }

    function isPaused() public view returns (bool)
    {
        return _paused;
    }

    function getNativeRewardToken() public view returns (address)
    {
        return _nativeRewardToken;
    }

    function getRewardSender() public view returns (address)
    {
        return _rewardSender;
    }

    function setRewardSender(
        address new_reward_sender
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_REWARD_SENDER)
    {
        _rewardSender = new_reward_sender;
    }

    function getName() public view returns (string memory)
    {
        return _name;
    }

    function setName(
        string memory new_name
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_NAME)
    {
        _name = new_name;
    }

    function getPublicKey() public view returns (string memory)
    {
        return _publicKey;
    }

    function setPublicKey(
        string memory new_public_key
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_PUBLIC_KEY)
    {
        _publicKey = new_public_key;
    }

    function getProofInstruction() public view returns (string memory)
    {
        return _proofInstruction;
    }

    function setProofInstruction(
        string memory new_proof_instruction
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_PROOF_INSTRUCTION)
    {
        _proofInstruction = new_proof_instruction;
    }

    function getFileRewardFactor() public view returns (uint256)
    {
        return _fileRewardFactor;
    }

    function setFileRewardFactor(
        uint256 new_file_reward_factor
    ) external permissionedCall(msg.sender, PERMISSION_UPDATE_FILE_REWARD_FACTOR)
    {
        _fileRewardFactor = new_file_reward_factor;
    }
}
