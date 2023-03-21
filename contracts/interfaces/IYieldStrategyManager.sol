// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./savvy/ISavvyTokenParams.sol";
import "./savvy/ISavvyErrors.sol";
import "./savvy/ISavvyEvents.sol";
import "./savvy/ISavvyAdminActions.sol";
import "./savvy/IYieldStrategyManagerStates.sol";
import "./savvy/IYieldStrategyManagerActions.sol";
import "../libraries/Limiters.sol";

/// @title  IYieldStrategyManager
/// @author Savvy DeFi
interface IYieldStrategyManager is 
    ISavvyTokenParams, 
    ISavvyErrors, 
    ISavvyEvents,
    IYieldStrategyManagerStates, 
    IYieldStrategyManagerActions 
{ }