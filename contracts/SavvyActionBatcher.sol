// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "./interfaces/IInfoAggregator.sol";
import "./interfaces/infoaggregator/ISavvyPositions.sol";
import "./interfaces/ISavvyActionBatcher.sol";
import "./interfaces/ISavvyPositionManager.sol";

import "./libraries/Checker.sol";

contract SavvyActionBatcher is ISavvyActionBatcher, Ownable2StepUpgradeable {

    /// @notice Address of InfoAggregator.
    IInfoAggregator public infoAggregator;

    function initialize (
        IInfoAggregator infoAggregator_
    ) public initializer {
        Checker.checkArgument(address(infoAggregator_) != address(0), "zero infoAggregator address");

        infoAggregator = infoAggregator_;
        __Ownable_init();
    }

    /// @inheritdoc ISavvyActionBatcher
    function borrowAllCredit(address recipient_) external override {
        address sender = msg.sender;
        Checker.checkArgument(sender != address(0), "zero sender address");
        Checker.checkArgument(recipient_ != address(0), "zero recipient address");

        ISavvyPositions.SavvyPosition[] memory borrowableAmounts = infoAggregator.getBorrowableAmount(sender);
        
        uint256 length = borrowableAmounts.length;
        for (uint256 i = 0; i < length; i ++) {
            uint256 borrowableAmount = borrowableAmounts[i].amount;
            address savvyPositionManager = borrowableAmounts[i].baseToken;
            if (savvyPositionManager != address(0) && borrowableAmount > 0) {
                ISavvyPositionManager(savvyPositionManager).borrowCreditFrom(sender, borrowableAmount, recipient_);
            }
        } 
    }

    uint256[100] private __gap;
}