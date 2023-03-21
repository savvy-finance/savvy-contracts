// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IllegalState} from "../../base/Errors.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "../../base/Errors.sol";
import "../../interfaces/ITokenAdapter.sol";
import "../../interfaces/external/yieldyak/IYieldYakVault.sol";
import "../../interfaces/external/IWAVAX9.sol";

import "../../libraries/TokenUtils.sol";
import "../../libraries/Checker.sol";

contract YieldYakAdapter is ITokenAdapter, Initializable, Ownable2StepUpgradeable {
    string public constant override version = "1.0.0";

    /// @notice Only SavvyPositionManager can call functions.
    mapping(address => bool) private isAllowlisted;

    address public override token;
    address public override baseToken;

    uint256 private baseTokenDecimals;
    bool private isWAVAX;
    address private WAVAX;

    modifier onlyPositionManager {
        require (isAllowlisted[msg.sender], "Only Position Manager");
        _;
    }

    constructor () {
      _disableInitializers();
    }

    function initialize(
        address _token, 
        address _baseToken,
        address _WAVAX
    ) public initializer {
        Checker.checkArgument(_token != address(0), "wrong token");
        WAVAX = _WAVAX;
        token = _token;
        baseToken = _baseToken;
        baseTokenDecimals = TokenUtils.expectDecimals(token);

        if (_baseToken == WAVAX) {
            isWAVAX = true;
        } else {
            isWAVAX = false;
        }

        __Ownable2Step_init();
    }

    /// @inheritdoc ITokenAdapter
    function price() external view override returns (uint256) {
        return IYieldYakVault(token).getDepositTokensForShares(10**baseTokenDecimals);
    }

    /// @inheritdoc ITokenAdapter
    function addAllowlist(address[] memory allowlistAddresses, bool status) external onlyOwner override {
        require (allowlistAddresses.length > 0, "invalid length");
        for (uint256 i = 0; i < allowlistAddresses.length; i ++) {
            isAllowlisted[allowlistAddresses[i]] = status;
        }
    }

    /// @inheritdoc ITokenAdapter
    function wrap(uint256 amount, address recipient) external onlyPositionManager override returns (uint256) {
        amount = TokenUtils.safeTransferFrom(baseToken, msg.sender, address(this), amount);
        TokenUtils.safeApprove(baseToken, token, amount);

        return _deposit(amount, recipient);
    }

   /// @inheritdoc ITokenAdapter
    function unwrap(uint256 amount, address recipient) external onlyPositionManager override returns (uint256) {
        amount = TokenUtils.safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 balanceBefore = TokenUtils.safeBalanceOf(token, address(this));

        uint256 amountWithdrawn = _withdraw(amount, recipient);

        uint256 balanceAfter = TokenUtils.safeBalanceOf(token, address(this));

        // If the Yearn vault did not burn all of the shares then revert. This is critical in mathematical operations
        // performed by the system because the system always expects that all of the tokens were unwrapped. In Yearn,
        // this sometimes does not happen in cases where strategies cannot withdraw all of the requested tokens (an
        // example strategy where this can occur is with Compound and AAVE where funds may not be accessible because
        // they were lent out).
        Checker.checkState(balanceBefore - balanceAfter == amount, "unwrap failed");

        return amountWithdrawn;
    }

    function _deposit(uint256 amount, address recipient) internal returns (uint256) {
        uint256 balanceBefore = IERC20(token).balanceOf(recipient);

        IYieldYakVault vault = IYieldYakVault(token);
        if (isWAVAX) {
            IWAVAX9(WAVAX).withdraw(amount);
            vault.depositFor{value: amount}(recipient);
        } else {
            vault.depositFor(recipient, amount);
        }

        uint256 balanceAfter = IERC20(token).balanceOf(recipient);
        uint256 receivedVaultTokens = balanceAfter - balanceBefore;

        return receivedVaultTokens;
    }

    function _withdraw(uint256 amount, address recipient) internal returns (uint256) {
        uint256 balanceBefore = _getBaseTokenBalance(address(this));
        IYieldYakVault(token).withdraw(amount);
        uint256 balanceAfter = _getBaseTokenBalance(address(this));
        uint256 receivedBaseTokens = balanceAfter - balanceBefore;

        if (isWAVAX) {
            IWAVAX9(WAVAX).deposit{value: receivedBaseTokens}();
        }
        TokenUtils.safeTransfer(baseToken, recipient, receivedBaseTokens);

        return receivedBaseTokens;
    }

    function _getBaseTokenBalance(address account) internal view returns (uint256 balance) {
        if (isWAVAX) {
            balance = account.balance;
        } else {
            balance = IERC20(baseToken).balanceOf(account);
        }
    }

    /// @dev Allows for payments from the WAVAX contract.
    receive() external payable {
    }

    uint256[100] private __gap;
}