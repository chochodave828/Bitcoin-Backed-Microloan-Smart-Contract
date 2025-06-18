# 🏦 Bitcoin-Backed Microloan Smart Contract

A decentralized lending platform built on Stacks blockchain where users can lock Bitcoin (STX) as collateral to receive stablecoin loans with automated repayment terms and liquidation mechanisms.

## 🚀 Features

- 💰 **Collateralized Loans**: Lock STX tokens to borrow stablecoins
- 📊 **150% Collateral Ratio**: Over-collateralized loans for security
- ⏰ **Fixed Terms**: 144 blocks loan duration with 5% interest
- 🔄 **Flexible Repayment**: Pay back loans partially or in full
- ⚡ **Auto-Liquidation**: Overdue loans can be liquidated by anyone
- 📈 **Real-time Tracking**: Monitor loan status and payments

## 🛠️ Contract Functions

### 📝 Core Functions

#### `create-loan`
```clarity
(create-loan collateral-amount loan-amount)
```
Create a new loan by providing STX collateral. Requires 150% collateralization ratio.

#### `repay-loan`
```clarity
(repay-loan loan-id payment-amount)
```
Make payments towards your loan. Full repayment releases collateral automatically.

#### `liquidate-loan`
```clarity
(liquidate-loan loan-id)
```
Liquidate overdue loans and earn 10% penalty reward.

### 👑 Admin Functions

#### `deposit-stablecoin`
```clarity
(deposit-stablecoin amount)
```
Owner-only function to add liquidity to the lending pool.

#### `withdraw-stablecoin`
```clarity
(withdraw-stablecoin amount)
```
Owner-only function to withdraw excess liquidity.

### 🔍 Read-Only Functions

#### `get-loan`
```clarity
(get-loan loan-id)
```
Retrieve complete loan information by ID.

#### `get-user-loans`
```clarity
(get-user-loans user-principal)
```
Get list of all loan IDs for a specific user.

#### `get-loan-status`
```clarity
(get-loan-status loan-id)
```
Get current status including amounts due and overdue status.

#### `calculate-required-collateral`
```clarity
(calculate-required-collateral loan-amount)
```
Calculate minimum collateral needed for a loan amount.

#### `get-contract-stats`
```clarity
(get-contract-stats)
```
Get overall contract statistics and parameters.

## 📋 Loan Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| 🔒 **Collateral Ratio** | 150% | Minimum collateral required |
| 💹 **Interest Rate** | 5% | Fixed interest on loan amount |
| ⏱️ **Loan Duration** | 144 blocks | Time limit for repayment |
| ⚠️ **Liquidation Penalty** | 10% | Reward for liquidators |

## 🎯 Usage Example

### Creating a Loan
```clarity
;; Lock 1500 STX to borrow 1000 stablecoins
(contract-call? .microloan create-loan u1500 u1000)
```

### Repaying a Loan
```clarity
;; Pay 500 stablecoins towards loan #1
(contract-call? .microloan repay-loan u1 u500)
```

### Checking Loan Status
```clarity
;; Check status of loan #1
(contract-call? .microloan get-loan-status u1)
```

## ⚠️ Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Loan not found |
| u102 | Insufficient collateral |
| u103 | Loan already exists |
| u104 | Loan not active |
| u105 | Insufficient payment |
| u106 | Loan overdue |
| u107 | Insufficient balance |
| u108 | Invalid amount |

## 🔐 Security Features

- ✅ Over-collateralization prevents bad debt
- ✅ Time-based liquidation mechanism
- ✅ Owner-controlled liquidity management
- ✅ Input validation on all functions
- ✅ Proper access control

## 🚀 Getting Started

1. Deploy the contract to Stacks testnet
2. Owner deposits stablecoins for lending
3. Users can create loans with STX collateral
4. Monitor and manage loans through read functions
5. Liquidate overdue loans for rewards

## 📊 Contract State

The contract maintains:
- Individual loan records with full details
- User loan mappings for easy lookup
- Contract balance tracking
- Global statistics and counters

Built with ❤️ using Clarity smart contracts on Stacks blockchain.
```

**Git Commit Message:**
```
feat: implement bitcoin-backed microloan smart contract with collateralized lending
```

**GitHub Pull Request Title:**
```
🏦 Add Bitcoin-Backed Microloan Smart Contract MVP
```

**GitHub Pull Request Description:**
```
## 🎯 Summary
Implements a complete microloan system allowing users to lock STX as collateral for stablecoin loans.

## ✨ Features Added
- Collateralized loan creation with 150% ratio requirement
- Flexible loan repayment system with interest calculation
- Automated liquidation mechanism for overdue
