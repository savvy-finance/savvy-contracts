// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./interfaces/ISavvyTestnetHelper.sol";
import "./interfaces/IERC20Mintable.sol";
import "./libraries/Math.sol";

/// @title SavvyTestnetHelper
/// @author Savvy DeFi
///
/// @notice Collection of testnet helpers.
/// @dev Used by the frontend.
contract SavvyTestnetHelper is Ownable2StepUpgradeable, ISavvyTestnetHelper {
    /// @notice The max amount of gas to allocate.
    uint256 public gasLimit;

    /// @notice Emit warning if balance is below the limit.
    uint256 public balanceWarningLimit;

    /// @notice Tokens to mint upon setup.
    MintDetails[] private mintDetails;

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 gasLimit_, uint256 balanceWarningLimit_)
        public
        initializer
    {
        gasLimit = gasLimit_;
        balanceWarningLimit = balanceWarningLimit_;
        __Ownable_init();
    }

    receive() external payable {}

    function getMintDetails() external view returns (MintDetails[] memory) {
        return mintDetails;
    }

    /// @inheritdoc ISavvyTestnetHelper
    function setBalanceWarningLimit(uint256 balanceWarningLimit_)
        external
        override
        onlyOwner
    {
        balanceWarningLimit = balanceWarningLimit_;
    }

    /// @inheritdoc ISavvyTestnetHelper
    function setGasLimit(uint256 gasLimit_) external override onlyOwner {
        gasLimit = gasLimit_;
    }

    /// @inheritdoc ISavvyTestnetHelper
    function setMintDetails(MintDetails[] memory mintDetails_)
        external
        override
        onlyOwner
    {
        delete mintDetails;

        uint256 numOfMintDetails = mintDetails_.length;
        for (uint256 i = 0; i < numOfMintDetails; i++) {
            mintDetails.push(mintDetails_[i]);
        }
    }

    /// @inheritdoc ISavvyTestnetHelper
    function withdrawAll() external override onlyOwner {
        uint256 balance = address(this).balance;
        _transferETH(msg.sender, balance);
        emit BalanceLow(0, gasLimit, balanceWarningLimit);
    }

    /// @inheritdoc ISavvyTestnetHelper
    function setupWalletForTestnet(address account_) external override {
        require(account_ != address(0), "Cannot be zero address");

        uint256 contractBalance = address(this).balance;
        uint256 accountBalance = account_.balance;

        if (accountBalance < gasLimit) {
            _transferETH(account_, Math.min(contractBalance, gasLimit));
            contractBalance = address(this).balance;
            if (contractBalance < balanceWarningLimit) {
                emit BalanceLow(contractBalance, gasLimit, balanceWarningLimit);
            }
        }

        uint256 numOfMintDetails = mintDetails.length;
        MintDetails memory details;
        IERC20Mintable token;
        uint256 amountToMint;
        for (uint256 i = 0; i < numOfMintDetails; i++) {
            details = mintDetails[i];
            token = IERC20Mintable(details.token);
            accountBalance = token.balanceOf(account_);
            if (accountBalance >= details.amountToMint) {
                continue;
            }

            amountToMint = details.amountToMint - accountBalance;
            token.mint(account_, amountToMint);
        }
    }

    function _transferETH(address recipient_, uint256 amount_) internal {
        (bool sent, ) = recipient_.call{value: amount_}("");
        require(sent, "Contract was not allowed to do the transfer");
    }
}
