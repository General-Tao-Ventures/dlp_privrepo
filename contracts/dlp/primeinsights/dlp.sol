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
import { IDataRegistry }                        from "../../dependencies/dataRegistry/interfaces/IDataRegistry.sol";
import { DataLiquidityPoolImplementation }      from "../DataLiquidityPoolImplementation.sol";

uint128 constant PERMISSION_FINISH_EPOCH            = 0x400;
//uint128 constant PERMISSION_SET_NATIVE_REWARD_TOKEN = 0x800;

uint128 constant PERMISSION_UPGRADE_CONTRACT        = 0x40000;

contract DLP is Permissions, Common, Contributions, Rewards, DLPInterface,
    UUPSUpgradeable,
    MulticallUpgradeable
{
    struct InitParams 
    {
        address ownerAddress;
        address dataRegistryAddress;
        string  name;
        string  publicKey;
        string  proofInstruction;
        uint256 fileRewardFactor;
    }
    
    function initialize(
        InitParams memory params
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

        _addRewardToken(address(0)); // native coin

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
            revert();
        }
    }

    function _finishEpoch() internal
    {
        require(_paused == 0x0, "Contract paused");
        updateScoresForContributionsAtEpoch(getCurrentEpoch());

        advanceEpoch();
    }

    function finishEpoch() external permissionedCall(msg.sender, PERMISSION_FINISH_EPOCH)
    {
        _finishEpoch();
    }

    function receiveNativeReward(
        uint256 reward_amount
    ) internal
    {
        require(reward_amount > 0);
        require(getNumContributors() > 0);
    
        //payable(msg.sender).transfer(reward_amount);
        addRewardForCurrentEpoch(address(0), reward_amount); // native coin

        //comment this if gas is an issue
        //need to finish epoch manually from permissioned wallet if it is
        if(_rewardSenderFinalizesEpoch && msg.sender == getRewardSender())
        {
            _finishEpoch();
        }
    }

    receive() external payable 
    {
        receiveNativeReward(msg.value);
    }

    fallback() external payable 
    {
        receiveNativeReward(msg.value);
    }
}

