// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./savvy/ISavvyActions.sol";
import "./savvy/ISavvyAdminActions.sol";
import "./savvy/ISavvyErrors.sol";
import "./savvy/ISavvyImmutables.sol";
import "./savvy/ISavvyEvents.sol";
import "./savvy/ISavvyState.sol";

/// @title  ISavvyPositionManager
/// @author Savvy DeFi
interface ISavvyPositionManager is
    ISavvyActions,
    ISavvyAdminActions,
    ISavvyErrors,
    ISavvyImmutables,
    ISavvyEvents,
    ISavvyState
{ }
