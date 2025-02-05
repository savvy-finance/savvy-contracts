// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IVeERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}