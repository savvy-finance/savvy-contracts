// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @title ISavvyTestnetHelper
/// @author Savvy DeFi
///
/// @notice Collection of testnet helpers.
/// @dev Used by the frontend.
interface ISavvyTestnetHelper {
    struct MintDetails {
        address token;
        uint256 amountToMint;
    }

    /// @notice Emitted when AVAX balance is low.
    ///
    /// @dev `currentBalance` / `gasLimit` = maximum number of
    /// wallets that can still be setup.
    ///
    /// @param currentBalance   The current AVAX balance.
    /// @param gasLimit         The AVAX given to users upon setup.
    /// @param balanceWarningLimit  The limit that triggered this event.
    event BalanceLow(
        uint256 currentBalance,
        uint256 gasLimit,
        uint256 balanceWarningLimit
    );

    /// @notice Set the ceiling for gas. `setupWalletForTestnet`
    /// will transfer difference between the caller's native balance
    /// and `gasLimit_`.
    /// @param gasLimit_ The gas ceiling.
    function setGasLimit(uint256 gasLimit_) external;

    /// @notice Set the balance warning limit. Will emit
    /// BalanceLow when the balance falls below this balance.
    /// @param balanceWarningLimit_ The balance limit to emit BalanceLow.
    function setBalanceWarningLimit(uint256 balanceWarningLimit_) external;

    /// @notice Set the initial mint details that will
    /// sent to the user upon setup.
    /// @param mintDetails_ Mint details to set.
    function setMintDetails(MintDetails[] memory mintDetails_) external;

    /// @notice Withdraw all Avax in this contract.
    function withdrawAll() external;

    /// @notice Simple way to setup a wallet for testnet.
    /// 1. Will send AVAX for gas if the account needs it.
    /// 2. Will mint a bit of every mock token.
    /// @dev emits BalanceLow if balance is lower than balanceLimitWarning.
    /// @param account_ The address to setup.
    function setupWalletForTestnet(address account_) external;
}
