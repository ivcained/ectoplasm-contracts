# Ectoplasm DEX Deployment Action Plan
## Casper Testnet Deployment

**Date:** December 21, 2025  
**Network:** Casper Testnet (`casper-test`)  
**Node:** `http://65.21.235.122:7777`  
**Deployer Account:** `01575cf230496820742ae11ed4d8d0d4fae9fdaa9bbad843dc80cf5dffb2869a28`

---

## Executive Summary

This document outlines the complete deployment strategy for the Ectoplasm Decentralized Exchange (DEX) on the Casper Testnet. The DEX implements an Automated Market Maker (AMM) model similar to Uniswap V2, supporting multiple trading pairs with CSPR, USDC, ECTO, ETH, and BTC tokens.

---

## 1. Deployment Status

### ✅ Completed Deployments

All core contracts and tokens have been successfully deployed to Casper Testnet:

#### Core DEX Contracts

| Contract | Package Hash | Transaction | Status |
|----------|-------------|-------------|---------|
| **Factory** | `c6c3cadda303246b4e7c953751e56ef36e1d804feb13515ff17f04f242a60bcd` | [63bcffdcbdc10ac1b55f82c9058e25add360e5c482da871a0598b0e11942f1f8](https://testnet.cspr.live/transaction/63bcffdcbdc10ac1b55f82c9058e25add360e5c482da871a0598b0e11942f1f8) | ✅ Deployed |
| **Router** | `c50d491c65e5cbc8ab859fe6e7d1253c24cf877258bf4579a59e6ce4d5d15275` | [4d0fc709cb5db25886f2a1dd798bbf941701a57e5e553c96aedadd4a257bc660](https://testnet.cspr.live/transaction/4d0fc709cb5db25886f2a1dd798bbf941701a57e5e553c96aedadd4a257bc660) | ✅ Deployed |
| **WCSPR (LpToken)** | `16eacd913f576394fbf114f652504e960367be71b560795fb9d7cf4d5c98ea68` | [7a18479cde38620dbb9b5e3ff7c9139cff8dc37deef10f9e4befc8ae65b87b61](https://testnet.cspr.live/transaction/7a18479cde38620dbb9b5e3ff7c9139cff8dc37deef10f9e4befc8ae65b87b61) | ✅ Deployed |

#### CEP-18 Tokens

| Token | Symbol | Decimals | Package Hash | Transaction | Status |
|-------|--------|----------|-------------|-------------|---------|
| **Ectoplasm Token** | ECTO | 18 | `295f699caebd9fa2bb15d0c3b5428919020a9b1c7a77054b1fd3318535c25a08` | [3dcb72b3724086600dd3a45d6e674d6f16a0bbc21608d5fe5b9dfaaa6332c82c](https://testnet.cspr.live/transaction/3dcb72b3724086600dd3a45d6e674d6f16a0bbc21608d5fe5b9dfaaa6332c82c) | ✅ Deployed |
| **USD Coin** | USDC | 6 | `ac04ecd8efd886a999c93990e901e313ffa8a6e29010bbbffcc5561b968bb52e` | [0951d568e4d36d8dd8dcba077140eac211af27e476d7b2454c6861f9cb9c4247](https://testnet.cspr.live/transaction/0951d568e4d36d8dd8dcba077140eac211af27e476d7b2454c6861f9cb9c4247) | ✅ Deployed |
| **Wrapped Ether** | WETH | 18 | `0ea123607a6b374442bf53d2fb4831ac364d9415ffd9e4895328038dbe31ea28` | [153101fe6f78a1d36a04742551219ab4cb96f9990483ca7a5ba58cd4b0d19b22](https://testnet.cspr.live/transaction/153101fe6f78a1d36a04742551219ab4cb96f9990483ca7a5ba58cd4b0d19b22) | ✅ Deployed |
| **Wrapped Bitcoin** | WBTC | 8 | `985924d7e134606c1fcd2d259e95d3a4831759b6c06d9d77629198439c43796b` | [8750b4c0c13f5bece84996b5a7345c8e6d2f0b76b09a5725f0685db4313c7cf7](https://testnet.cspr.live/transaction/8750b4c0c13f5bece84996b5a7345c8e6d2f0b76b09a5725f0685db4313c7cf7) | ✅ Deployed |

---

## 2. Architecture Overview

### DEX Components

```
┌─────────────────────────────────────────────────────────┐
│                    Ectoplasm DEX                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐    │
│  │ Factory  │◄────►│  Router  │◄────►│  WCSPR   │    │
│  └────┬─────┘      └──────────┘      └──────────┘    │
│       │                                                │
│       │ creates                                        │
│       ▼                                                │
│  ┌──────────┐                                         │
│  │   Pair   │  (Created dynamically for each pair)    │
│  └──────────┘                                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
                         │
                         │ interacts with
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  CEP-18 Tokens                          │
├─────────────────────────────────────────────────────────┤
│  CSPR  │  ECTO  │  USDC  │  WETH  │  WBTC             │
└─────────────────────────────────────────────────────────┘
```

### Contract Relationships

1. **Factory Contract**: Creates and manages trading pairs
2. **Router Contract**: Provides user-friendly interface for swaps and liquidity operations
3. **Pair Contracts**: Individual AMM pools for token pairs (created on-demand)
4. **Token Contracts**: CEP-18 compliant tokens for trading

---

## 3. Supported Trading Pairs

The DEX is designed to support the following trading pairs:

### Primary Pairs (CSPR-based)
1. **CSPR/USDC** - Native token to stablecoin
2. **CSPR/ECTO** - Native token to platform token
3. **CSPR/WETH** - Native token to wrapped Ethereum
4. **CSPR/WBTC** - Native token to wrapped Bitcoin

### Secondary Pairs (USDC-based)
5. **USDC/ECTO** - Stablecoin to platform token
6. **USDC/WETH** - Stablecoin to wrapped Ethereum
7. **USDC/WBTC** - Stablecoin to wrapped Bitcoin

---

## 4. Next Steps for Full DEX Operation

### Phase 1: Pair Creation (Not Yet Completed)

Note: Full AMM operation depends on `create_pair` actually creating/initializing on-chain Pair contracts. Before proceeding with liquidity/swaps, first verify that calling `create_pair`:
- increases `all_pairs_length`, and
- makes `get_pair(token_a, token_b)` return a non-empty address.

To create trading pairs, use the Factory contract's `create_pair` function:

```bash
# Example: Create CSPR/USDC pair
cd ectoplasm-contracts
export $(grep -v '^#' .env | grep -v '^$' | xargs)
./target/release/ectoplasm_contracts_cli scenario create-pair \
  --token_a "hash-16eacd913f576394fbf114f652504e960367be71b560795fb9d7cf4d5c98ea68" \
  --token_b "hash-ac04ecd8efd886a999c93990e901e313ffa8a6e29010bbbffcc5561b968bb52e"
```

Repeat for all 7 trading pairs listed above.

### Phase 2: Initial Liquidity Provision (Not Yet Completed)

After creating pairs, add initial liquidity using the Router contract:

```bash
# Example: Add liquidity to CSPR/USDC pair
# This requires:
# 1. Minting tokens to the deployer account
# 2. Approving Router to spend tokens
# 3. Calling add_liquidity on Router
```

### Phase 3: Testing and Verification

1. **Verify Pair Creation**: Check that all pairs exist in Factory
2. **Test Swaps**: Execute test swaps between different tokens
3. **Verify Liquidity**: Confirm LP tokens are minted correctly
4. **Test Removals**: Verify liquidity can be removed

---

## 5. Technical Specifications

### Gas Limits Used

| Operation | Gas Limit (motes) | Gas Limit (CSPR) |
|-----------|-------------------|------------------|
| Factory Deployment | 500,000,000,000 | 500 CSPR |
| Router Deployment | 500,000,000,000 | 500 CSPR |
| Token Deployment | 600,000,000,000 | 600 CSPR |
| Pair Creation | 300,000,000,000 | 300 CSPR |

### Total Deployment Cost

- **Factory**: ~667 CSPR
- **WCSPR Token**: ~600 CSPR  
- **Router**: ~400 CSPR
- **ECTO Token**: ~600 CSPR
- **USDC Token**: ~600 CSPR
- **WETH Token**: ~600 CSPR
- **WBTC Token**: ~600 CSPR

**Total**: ~4,067 CSPR

### Remaining Balance

Current account balance: ~3,515 CSPR (sufficient for pair creation and testing)

---

## 6. Contract Interfaces

### Factory Contract

```rust
// Create a new trading pair
pub fn create_pair(&mut self, token_a: Address, token_b: Address) -> Address

// Get pair address for two tokens
pub fn get_pair(&self, token_a: Address, token_b: Address) -> Option<Address>

// Get all pairs
pub fn all_pairs(&self) -> Vec<Address>
```

### Router Contract

```rust
// Add liquidity to a pair
pub fn add_liquidity(
    &mut self,
    token_a: Address,
    token_b: Address,
    amount_a_desired: U256,
    amount_b_desired: U256,
    amount_a_min: U256,
    amount_b_min: U256,
    to: Address,
    deadline: u64
) -> (U256, U256, U256)

// Remove liquidity from a pair
pub fn remove_liquidity(
    &mut self,
    token_a: Address,
    token_b: Address,
    liquidity: U256,
    amount_a_min: U256,
    amount_b_min: U256,
    to: Address,
    deadline: u64
) -> (U256, U256)

// Swap exact tokens for tokens
pub fn swap_exact_tokens_for_tokens(
    &mut self,
    amount_in: U256,
    amount_out_min: U256,
    path: Vec<Address>,
    to: Address,
    deadline: u64
) -> Vec<U256>
```

### Token Contracts (CEP-18)

```rust
// Standard CEP-18 interface
pub fn transfer(&mut self, to: Address, amount: U256) -> bool
pub fn approve(&mut self, spender: Address, amount: U256) -> bool
pub fn transfer_from(&mut self, from: Address, to: Address, amount: U256) -> bool
pub fn balance_of(&self, owner: Address) -> U256
pub fn allowance(&self, owner: Address, spender: Address) -> U256
pub fn total_supply(&self) -> U256

// Additional functions for testing
pub fn mint(&mut self, to: Address, amount: U256)
pub fn burn(&mut self, from: Address, amount: U256)
```

---

## 7. Security Considerations

### Implemented Security Features

1. **Reentrancy Protection**: All state changes occur before external calls
2. **Integer Overflow Protection**: Using U256 with checked arithmetic
3. **Minimum Liquidity Lock**: First 1000 LP tokens are locked forever
4. **Deadline Checks**: All time-sensitive operations require deadline parameter
5. **Slippage Protection**: Minimum amount parameters prevent excessive slippage

### Recommended Security Practices

1. **Audit**: Conduct thorough security audit before mainnet deployment
2. **Testing**: Extensive testing on testnet with various scenarios
3. **Monitoring**: Set up monitoring for unusual activity
4. **Upgradability**: Consider upgrade mechanisms for critical bugs
5. **Access Control**: Implement proper access control for admin functions

---

## 8. Integration Guide

### For Frontend Developers

#### Connect to Contracts

On Casper, frontend integration is split into:
- **Reads**: RPC state queries (no signing).
- **Writes**: signed transactions (wallet signing in browser, or `casper-client`/backend signer).

This repo already includes a working reference for reads:
- `tools/odra-state-reader-ts` (Casper JS SDK v5 + Odra dictionary reads)

#### Query Pair Information

Avoid assuming EVM-style "call contract getter" APIs like `queryContractData(...)`.

For Odra contracts, state is typically stored under the `state` dictionary. Use the TS reader approach (dictionary lookups + decoding) to read values.

#### Execute Swap

Swaps require a signed transaction. In browser, that usually means:
- build transaction payload (entrypoint + args),
- have a wallet sign it,
- submit to node RPC.

### For Backend Developers

#### Monitor DEX Activity

```javascript
// Subscribe to events
const eventStream = client.nodeClient.subscribeEvents({
  eventHandlerFn: (event) => {
    if (event.body.DeployProcessed) {
      // Handle swap, liquidity add/remove events
      processEvent(event);
    }
  }
});
```

---

## 9. Testing Checklist

### Pre-Production Testing

- [ ] Create all 7 trading pairs
- [ ] Add initial liquidity to each pair
- [ ] Test token swaps in both directions
- [ ] Test liquidity addition with various amounts
- [ ] Test liquidity removal
- [ ] Test edge cases (zero amounts, insufficient balance, etc.)
- [ ] Verify LP token minting and burning
- [ ] Test deadline expiration
- [ ] Test slippage protection
- [ ] Verify event emissions

### Performance Testing

- [ ] Measure gas costs for common operations
- [ ]