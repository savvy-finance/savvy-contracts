// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IVesperVault is IERC20Upgradeable {
    function name() external view returns (string memory);

    function pricePerShare() external view returns (uint256);

    function deposit() external payable;

    function deposit(uint256 amount) external;

    function withdraw(uint256 shares) external;

    function withdrawETH(uint256 shares) external;
}
