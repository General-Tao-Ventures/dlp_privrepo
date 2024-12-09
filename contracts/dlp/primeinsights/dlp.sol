// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { Common }                               from "./common.sol";
import { Rewards }                              from "./rewards.sol";
import { Contributions }                        from "./contributions.sol";
import { Permissions }                          from "./permissions.sol";
import { DLPInterface }                         from "./interface.sol";
import { TEEPool }                              from "./tee.sol";
import { ITeePool }                             from "../../dependencies/teePool/interfaces/ITeePool.sol";
import { IDataRegistry }                        from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { DataLiquidityPoolImplementation }      from "../DataLiquidityPoolImplementation.sol";

uint128 constant PERMISSION_FINISH_EPOCH            = 0x400;
uint128 constant PERMISSION_SET_NATIVE_REWARD_TOKEN = 0x800;

uint128 constant PERMISSION_UPGRADE_CONTRACT        = 0x40000;

contract DLP is Permissions, Common, Contributions, Rewards, TEEPool, DLPInterface,
    UUPSUpgradeable,
    MulticallUpgradeable
{
    function initialize(
        DataLiquidityPoolImplementation.InitParams memory params
    ) external initializer
    {
        //__Ownable2Step_init();
        __Multicall_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _name               = params.name;
        _publicKey          = params.publicKey;
        _proofInstruction   = params.proofInstruction;
        _fileRewardFactor   = params.fileRewardFactor;

        _dataRegistry       = IDataRegistry(params.dataRegistryAddress);
        _nativeRewardToken  = params.tokenAddress;
        _teePool            = ITeePool(params.teePoolAddress);

        _addRewardToken(params.tokenAddress);

        _superadminAddress  = params.ownerAddress;
        //_transferOwnership(params.ownerAddress);
    }

    constructor()
    {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address new_implementation
    ) internal virtual override
    {
        if(!checkPermissionForUser(msg.sender, PERMISSION_UPGRADE_CONTRACT))
        {
            revert("Not authorized to upgrade");
        }
    }

    function _finishEpoch() internal
    {
        require(!_paused, "Contract is paused");
        updateScoresForContributionsAtEpoch(getCurrentEpoch());

        advanceEpoch();
    }

    function finishEpoch() external permissionedCall(msg.sender, PERMISSION_FINISH_EPOCH)
    {
        _finishEpoch();
    }

    event NativeRewardTokenChanged(uint64 indexed epoch, address new_reward_token);
    function setNativeRewardToken(
        address new_native_reward_token
    ) external permissionedCall(msg.sender, PERMISSION_SET_NATIVE_REWARD_TOKEN)
    {
        require(isRewardTokenActive(new_native_reward_token), "Token is not active.");
        _nativeRewardToken = new_native_reward_token;

        emit NativeRewardTokenChanged(getCurrentEpoch(), new_native_reward_token);
    }

    function addRewardsForContributors(uint256 reward_amount) external
    {
        require(getNativeRewardToken() != address(0), "Native reward token not set");
        require(getNumContributors() > 0, "No contributors");
        require(getRewardSender() == msg.sender, "Only reward sender can add rewards/advance epoch");

        receiveToken(getNativeRewardToken(), reward_amount);

        _finishEpoch();
    }
}
