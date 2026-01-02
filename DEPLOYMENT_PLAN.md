# Ectoplasm DEX Deployment Action Plan - Casper Testnet

## 📋 Overview

This document outlines the complete deployment strategy for the Ectoplasm Decentralized Exchange on the Casper Testnet, including the following token pairs:

- **CSPR** (Native Casper Token)
- **USDC** (USD Coin - Wrapped)
- **ECTO** (Ectoplasm Token)
- **ETH** (Wrapped Ethereum)
- **BTC** (Wrapped Bitcoin)

## 🌐 CSPR.cloud API Endpoints (Testnet)

Based on the CSPR.cloud documentation:

| Service | Endpoint |
|---------|----------|
| REST API | `https://api.testnet.cspr.cloud` |
| Streaming API | `wss://streaming.testnet.cspr.cloud` |
| Node RPC API | `https://node.testnet.cspr.cloud` |
| Node SSE API | `https://node-sse.testnet.cspr.cloud` |

**Important**:
- `casper-client` does not support custom HTTP headers, so you generally cannot use it against an RPC endpoint that requires an `Authorization` header.
- Use a plain RPC endpoint (no auth) with `casper-client`, or use an SDK (e.g. `casper-js-sdk` v5) if you must set headers.

For the rest of this plan, assume you have a node RPC endpoint you can access without extra headers.

---

## 📅 Deployment Phases

### Phase 1: Environment Setup & Prerequisites

#### 1.1 Obtain CSPR.cloud API Access
- [ ] Register at [CSPR.cloud](https://cspr.cloud)
- [ ] Obtain API access token for testnet
- [ ] Verify API connectivity:
```bash
curl -X GET 'https://node.testnet.cspr.cloud/status' \
  -H 'Authorization: YOUR_API_KEY'
```

#### 1.2 Create Deployment Wallet
- [ ] Generate a new Casper keypair for deployment:
```bash
casper-client keygen ./keys
```
- [ ] Fund wallet from Casper Testnet Faucet: https://testnet.cspr.live/tools/faucet
- [ ] Verify balance via CSPR.cloud API:
```bash
curl -X GET 'https://api.testnet.cspr.cloud/accounts/YOUR_ACCOUNT_HASH' \
  -H 'Authorization: YOUR_API_KEY'
```

#### 1.3 Build Environment Setup
- [ ] Install Rust nightly toolchain
- [ ] Install Odra CLI: `cargo install odra-cli`
- [ ] Install casper-client: `cargo install casper-client`
- [ ] Verify toolchain:
```bash
rustup show
cargo odra --version
casper-client --version
```

---

### Phase 2: Smart Contract Compilation

#### 2.1 Build All Contracts
```bash
cd ectoplasm-contracts
cargo odra build
```

This will compile the following WASM contracts:
- `LpToken.wasm` - LP token contract
- `Pair.wasm` - Trading pair contract
- `Factory.wasm` - Pair factory contract
- `Router.wasm` - Main router contract

#### 2.2 Verify Build Output
- [ ] Check `wasm/` directory for compiled contracts
- [ ] Verify contract sizes (should be < 1MB each for optimal gas)
- [ ] Generate contract schemas:
```bash
cargo run --bin ectoplasm_contracts_build_schema
```

---

### Phase 3: Token Deployment (CEP-18 Tokens)

Deploy tokens for the DEX.

In this repo, the test tokens are implemented as separate Odra modules in `src/tokens.rs` and compile to separate WASMs:
- `EctoToken.wasm`, `UsdcToken.wasm`, `WethToken.wasm`, `WbtcToken.wasm`

WCSPR is deployed using `LpToken.wasm` (initialized with `name` + `symbol`).

Odra installers expect the `odra_cfg_*` args (same as the Odra tutorial) so the deploy writes a named key with the resulting **package hash**.

#### 3.1 Deploy ECTO Token (Native DEX Token)
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/EctoToken.wasm \
  --payment-amount 150000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'ecto_token_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'"
```

#### 3.2 Deploy Wrapped USDC
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/UsdcToken.wasm \
  --payment-amount 150000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'usdc_token_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'"
```

#### 3.3 Deploy Wrapped ETH
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/WethToken.wasm \
  --payment-amount 150000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'weth_token_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'"
```

#### 3.4 Deploy Wrapped BTC
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/WbtcToken.wasm \
  --payment-amount 150000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'wbtc_token_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'"
```

#### 3.5 Deploy Wrapped CSPR (WCSPR)
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/LpToken.wasm \
  --payment-amount 150000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'wcspr_token_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'" \
  --session-arg "name:string:'Wrapped CSPR'" \
  --session-arg "symbol:string:'WCSPR'"
```

#### 3.6 Verify Token Deployments
Track each transaction via node RPC:
```bash
casper-client get-transaction --node-address http://YOUR_NODE_HOST:7777 <TX_HASH>
```

Record contract hashes:
| Token | Contract Hash | Package Hash |
|-------|---------------|--------------|
| ECTO  | `hash-...`    | `hash-...`   |
| USDC  | `hash-...`    | `hash-...`   |
| WETH  | `hash-...`    | `hash-...`   |
| WBTC  | `hash-...`    | `hash-...`   |
| WCSPR | `hash-...`    | `hash-...`   |

---

### Phase 4: DEX Core Contract Deployment

#### 4.1 Deploy Factory Contract
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/Factory.wasm \
  --payment-amount 200000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'factory_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'" \
  --session-arg "fee_to_setter:key='account-hash-YOUR_ACCOUNT_HASH'"
```

#### 4.2 Deploy Router Contract
```bash
casper-client put-transaction session \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --wasm-path ./wasm/Router.wasm \
  --payment-amount 200000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --install-upgrade \
  --session-arg "odra_cfg_package_hash_key_name:string:'router_package_hash'" \
  --session-arg "odra_cfg_allow_key_override:bool:'true'" \
  --session-arg "odra_cfg_is_upgradable:bool:'true'" \
  --session-arg "odra_cfg_is_upgrade:bool:'false'" \
  --session-arg "factory:key='hash-FACTORY_CONTRACT_HASH'" \
  --session-arg "wcspr:key='hash-WCSPR_CONTRACT_HASH'"
```

#### 4.3 Verify DEX Deployments
The deploy stores the **package hashes** under your account named keys (based on the `odra_cfg_package_hash_key_name`).

You can fetch your account named keys via RPC and record the package hashes:
```bash
casper-client get-account \
  --node-address http://YOUR_NODE_HOST:7777 \
  --account-identifier account-hash-YOUR_ACCOUNT_HASH
```

---

### Phase 5: Create Trading Pairs

#### 5.1 Create CSPR/USDC Pair
```bash
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-WCSPR_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-USDC_CONTRACT_HASH'"
```

#### 5.2 Create CSPR/ECTO Pair
```bash
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-WCSPR_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-ECTO_CONTRACT_HASH'"
```

#### 5.3 Create CSPR/ETH Pair
```bash
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-WCSPR_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-WETH_CONTRACT_HASH'"
```

#### 5.4 Create CSPR/BTC Pair
```bash
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-WCSPR_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-WBTC_CONTRACT_HASH'"
```

#### 5.5 Create Additional Pairs (USDC pairs)
```bash
# USDC/ECTO
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-USDC_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-ECTO_CONTRACT_HASH'"

# USDC/ETH
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-USDC_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-WETH_CONTRACT_HASH'"

# USDC/BTC
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 100000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-FACTORY_PACKAGE_HASH \
  --session-entry-point create_pair \
  --session-arg "token_a:key='hash-USDC_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-WBTC_CONTRACT_HASH'"
```

---

### Phase 6: Add Initial Liquidity

#### 6.1 Approve Tokens for Router
Before adding liquidity, approve the Router to spend tokens:

```bash
# Approve WCSPR
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 5000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-WCSPR_PACKAGE_HASH \
  --session-entry-point approve \
  --session-arg "spender:key='hash-ROUTER_CONTRACT_HASH'" \
  --session-arg "amount:u256='1000000000000000000000000'"

# Repeat for each token (USDC, ECTO, WETH, WBTC)
```

#### 6.2 Add Liquidity to CSPR/USDC Pool
```bash
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 50000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-ROUTER_PACKAGE_HASH \
  --session-entry-point add_liquidity \
  --session-arg "token_a:key='hash-WCSPR_CONTRACT_HASH'" \
  --session-arg "token_b:key='hash-USDC_CONTRACT_HASH'" \
  --session-arg "amount_a_desired:u256='10000000000000'" \
  --session-arg "amount_b_desired:u256='1000000000'" \
  --session-arg "amount_a_min:u256='9500000000000'" \
  --session-arg "amount_b_min:u256='950000000'" \
  --session-arg "to:key='account-hash-YOUR_ACCOUNT_HASH'" \
  --session-arg "deadline:u64='<UNIX_SECONDS_IN_FUTURE>'"
```

For verification/testing/monitoring steps, continue in `DEPLOYMENT_PLAN_PART2.md`.