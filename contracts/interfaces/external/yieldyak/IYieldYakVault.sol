// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IYieldYakVault is IERC20Upgradeable {
    function name() external view returns (string memory);

    function getDepositTokensForShares(uint256) external view returns (uint256);

    function deposit() external payable;

    function deposit(uint256 amount) external;

    function depositFor(address account) external payable;

    function depositFor(address account, uint256 amount) external;

    function withdraw(uint256 amount) external;
}
