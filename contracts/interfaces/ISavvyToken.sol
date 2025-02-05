// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title  ISavvyToken
/// @author Savvy DeFi
interface ISavvyToken is IERC20 {
  /// @notice Gets the total amount of minted tokens for an account.
  ///
  /// @param account The address of the account.
  ///
  /// @return The total minted.
  function hasMinted(address account) external view returns (uint256);

  /// @notice Lowers the number of tokens which the `msg.sender` has minted.
  ///
  /// This reverts if the `msg.sender` is not allowlisted.
  ///
  /// @param amount The amount to lower the minted amount by.
  function lowerHasMinted(uint256 amount) external;

  /// @notice Sets the mint allowance for a given account'
  ///
  /// This reverts if the `msg.sender` is not admin
  ///
  /// @param toSetCeiling The account whos allowance to update
  /// @param ceiling      The amount of tokens allowed to mint
  function setCeiling(address toSetCeiling, uint256 ceiling) external;

  /// @notice Updates the state of an address in the allowlist map
  ///
  /// This reverts if msg.sender is not admin
  ///
  /// @param toAllowlist the address whos state is being updated
  /// @param state the boolean state of the allowlist
  function setAllowlist(address toAllowlist, bool state) external;

  function mint(address recipient, uint256 amount) external;

  function burn(uint256 amount) external;
}