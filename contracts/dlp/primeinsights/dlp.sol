// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

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

contract DLP is Permissions, Common, Contributions, Rewards, DLPInterface, TEEPool,
    UUPSUpgradeable,
    PausableUpgradeable,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    MulticallUpgradeable
{
    function initialize(
        DataLiquidityPoolImplementation.InitParams memory params
    ) external initializer
    {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _addRewardToken(params.tokenAddress);

        //name = params.name;
        _dataRegistry = IDataRegistry(params.dataRegistryAddress);
        _nativeRewardToken = params.tokenAddress;
        _teePool = ITeePool(params.teePoolAddress);
        //publicKey = params.publicKey;
        //proofInstruction = params.proofInstruction;
        //fileRewardFactor = params.fileRewardFactor;

        _transferOwnership(params.ownerAddress);
        _superadminAddress = params.ownerAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    constructor() 
    {
        _disableInitializers();
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
        //require(getRewardSender() == msg.sender, "Only reward sender can add rewards");

        receiveToken(getNativeRewardToken(), reward_amount);

        _finishEpoch();
    }
}
