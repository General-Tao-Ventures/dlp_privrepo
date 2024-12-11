// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Multisig is Initializable, ReentrancyGuard
{
    struct Call 
    {
        address to;
        uint256 value;
        bytes   data;
        bool    executed;
    }

    address[]                       internal _signers;
    uint16                          internal _threshold;
    Call[]                          internal _calls;
    mapping(uint256 => address[])   internal _signatures;

    function initialize(
        address[] memory signers,
        uint16 threshold
    ) external initializer
    {
        _signers    = signers;
        _threshold  = threshold;
    }

    constructor()
    {
        _disableInitializers();
    }

    event CallAdded(uint256 call_id, address signer);
    function addCall(
        address         to,
        uint256         value,
        bytes memory    data
    ) external
    {
        require(isSigner(msg.sender), "Not a signer");

        _calls.push(Call(to, value, data, false));
        _signatures[_calls.length - 1].push(msg.sender);

        emit CallAdded(_calls.length - 1, msg.sender);
    }

    function isSigner(
        address signer
    ) public view returns (bool)
    {
        for(uint256 i = 0; i < _signers.length; i++)
        {
            if(_signers[i] == signer)
            {
                return true;
            }
        }

        return false;
    }

    function hasSigned(
        uint256 call_id,
        address signer
    ) public view returns (bool)
    {
        for(uint256 i = 0; i < _signatures[call_id].length; i++)
        {
            if(_signatures[call_id][i] == signer)
            {
                return true;
            }
        }

        return false;
    }

    event CallSigned(uint256 call_id, address signer);
    function signCall(
        uint256 call_id
    ) external nonReentrant  returns (bool, bytes memory) 
    {
        require(call_id < _calls.length, "Invalid call id");
        require(isSigner(msg.sender), "Not a signer");
        require(!hasSigned(call_id, msg.sender), "Already signed");
        
        _signatures[call_id].push(msg.sender);
        if(_signatures[call_id].length >= _threshold)
        {
            return executeCall(call_id);
        }
        else
        {
            emit CallSigned(call_id, msg.sender);
        }

        return (true, bytes(""));
    }

    event CallExecuted(uint256 call_id, bool success, bytes data);
    function executeCall(
        uint256 call_id
    ) internal returns (bool, bytes memory)
    {
        Call memory call                    = _calls[call_id];
        require(!call.executed, "Call already executed");
        require(call.value == msg.value, "Invalid value");

        _calls[call_id].executed = true;
        (bool success, bytes memory data)   = address(call.to).call{
            value: call.value
        }(call.data);

        delete _signatures[call_id];

        emit CallExecuted(call_id, success, data);

        return (success, data);
    }
}