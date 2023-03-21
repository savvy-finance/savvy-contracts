# Savvy DeFi

Savvy is an auto-repaying and non-liquidating DeFi lending platform that gives users the ability to take an advance on their future yield immediately.

🌐  [website](https://savvydefi.io/)  
📝  [whitepaper](http://whitepaper.savvydefi.io/)

## Terms
| Term | Description | Example |
| ---- | ----------- | ------- |
| **Protocol Token** | ERC20 that represents governance for the protocol. | $SVY |
| **Deposit Token** | ERC20 that represents what the LGE accepts purchases with. | $USDC |
| **Base Token** | ERC20 of acceptable collateral. | $DAI, $ETH, $AVAX, $BTC |
| **Yield Token** | ERC20 of yield-bearing token representing the position in an external yield strategy. | $mooCurveAv3CRV
| **Synthetic Token** | ERC20 of svAsset that is soft-pegged to corresponding base token. | $svUSD, $svETH, $svAVAX, $svBTC

## Development

### Repo Structure
| Path | Description |
| ---- | ----------- |
| ~ | Repo root. |
| ~/contracts | Savvy smart contracts. |
| ~/contracts/adapters | Connect to external yield strategies. |
| ~/contracts/interfaces | Public interfaces for smart contracts. |
| ~/contracts/test | Smart contract mocks to enable E2E testing in testnet. |
| ~/test | Unit tests for Savvy logic. |


### Getting Started

**Setup .env file**  
Create a copy of `~/.env.example` called `~/.env` in the root of your project. Open `~/.env` and replace the example values with your own values.

**Install dependencies**  
`npm i`

**Compile smart contracts**  
`npx hardhat compile`

**Run unit tests**  
`npx hardhat test`
