// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @title ISavvyActionBatcher
/// @author Savvy DeFi
///
/// @notice Batches various Savvy actions.
/// @dev Used by the frontend.  
interface ISavvyActionBatcher {
    /// @notice `Recipient` to borrow the maximum credit from all sender's SavvyPositionManagers.
    /// @param recipient_ The address to receiving the credit.
    function borrowAllCredit(address recipient_) external;
}