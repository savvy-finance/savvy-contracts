// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./base/Multicall.sol";
import "./base/Mutex.sol";
import "./base/ErrorMessages.sol";

import "./libraries/TokenUtils.sol";
import "./libraries/SafeCast.sol";
import "./libraries/Checker.sol";

import "./interfaces/ISavvyLoanMigrator.sol";
import "./interfaces/ISavvyToken.sol";
import "./interfaces/ISavvyPositionManager.sol";
import "./interfaces/IYieldStrategyManager.sol";
import "./interfaces/savvy/ISavvyState.sol";
import "./interfaces/external/IWAVAX9.sol";

contract SavvyLoanMigrator is ISavvyLoanMigrator, Multicall, Initializable {
    string public override version;
    uint256 FIXED_POINT_SCALAR;

    mapping(address => uint256) public decimals;

    ISavvyPositionManager public savvyPositionManager;
    IYieldStrategyManager public yieldStrategyManager;
    ISavvyToken public savvyToken;
    address[] public collateralAddresses;

    constructor () {
      _disableInitializers();
    }

    function initialize(InitializationParams memory params) public initializer {
        uint size = params.collateralAddresses.length;

        savvyPositionManager       = ISavvyPositionManager(params.savvyPositionManager);
        yieldStrategyManager          = savvyPositionManager.yieldStrategyManager();
        savvyToken   = ISavvyToken(savvyPositionManager.debtToken());
        collateralAddresses = params.collateralAddresses;

        for(uint i = 0; i < size; i++){
            decimals[collateralAddresses[i]] = TokenUtils.expectDecimals(collateralAddresses[i]);
        }

        version = "1.0.0";
        FIXED_POINT_SCALAR = 1e18;
    }

    /// @inheritdoc ISavvyLoanMigrator
    function migrateVaults(
        address startingYieldToken,
        address targetYieldToken,
        uint256 shares,
        uint256 minReturnShares,
        uint256 minReturnUnderlying
    ) external override returns (uint256) {
        // yield tokens cannot be the same to prevent slippage on current position
        Checker.checkArgument(startingYieldToken != targetYieldToken, "yield tokens cannot be the same");

        // If either yield token is invalid, revert
        Checker.checkArgument(yieldStrategyManager.isSupportedYieldToken(startingYieldToken), "starting yield token is not supported");

        Checker.checkArgument(yieldStrategyManager.isSupportedYieldToken(targetYieldToken), "target yield token is not supported");

        ISavvyState.YieldTokenParams memory startingParams = yieldStrategyManager.getYieldTokenParameters(startingYieldToken);
        ISavvyState.YieldTokenParams memory targetParams = yieldStrategyManager.getYieldTokenParameters(targetYieldToken);

        // If starting and target base tokens are not the same then revert
        Checker.checkArgument(startingParams.baseToken == targetParams.baseToken, "Cannot swap between different collaterals");

        // Original debt
        (int256 debt, ) = savvyPositionManager.accounts(msg.sender);

        // Avoid calculations and repayments if user doesn't need this to migrate
        uint256 debtTokenValue;
        uint256 mintable;
        if (debt > 0) {
            // Convert shares to amount of debt tokens
            debtTokenValue = _convertToDebt(shares, startingYieldToken, startingParams.baseToken);
            mintable = debtTokenValue * FIXED_POINT_SCALAR / savvyPositionManager.minimumCollateralization();
            // Mint tokens to this contract and burn them in the name of the user
            savvyToken.mint(address(this), mintable);
            TokenUtils.safeApprove(address(savvyToken), address(savvyPositionManager), mintable);
            savvyPositionManager.repayWithDebtToken(mintable, msg.sender);
        }

        // Withdraw what you can from the old position
        uint256 underlyingWithdrawn = savvyPositionManager.withdrawBaseTokenFrom(
            msg.sender, 
            startingYieldToken, 
            shares, 
            address(this), 
            minReturnUnderlying
        );

        // Deposit into new position
        TokenUtils.safeApprove(targetParams.baseToken, address(savvyPositionManager), underlyingWithdrawn);
        uint256 newPositionShares = savvyPositionManager.depositBaseToken(targetYieldToken, underlyingWithdrawn, msg.sender, minReturnShares);

        if (debt > 0) {
            (int256 latestDebt, ) = savvyPositionManager.accounts(msg.sender);
            // Mint al token which will be burned to fulfill flash loan requirements
            savvyPositionManager.borrowCreditFrom(msg.sender, SafeCast.toUint256(debt - latestDebt), address(this));
            savvyToken.burn(savvyToken.balanceOf(address(this)));
        }

	    return newPositionShares;
	}

    function _convertToDebt(
        uint256 shares, 
        address yieldToken, 
        address baseToken
    ) internal view returns(uint256) {
        // Math safety
        Checker.checkState(TokenUtils.expectDecimals(baseToken) <= 18, "Base token decimals exceeds 18");

        uint256 underlyingValue = shares * yieldStrategyManager.getBaseTokensPerShare(yieldToken) / 10**TokenUtils.expectDecimals(yieldToken);
        return underlyingValue * 10**(18 - decimals[baseToken]);
    }

    uint256[100] private __gap;
}