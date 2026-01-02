# Ectoplasm DEX Deployment Action Plan - Part 2

## Phase 6: Add Initial Liquidity (Continued)

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
  --session-arg "token_a:key='hash-WCSPR_PACKAGE_HASH'" \
  --session-arg "token_b:key='hash-USDC_PACKAGE_HASH'" \
  --session-arg "amount_a_desired:u256='10000000000000'" \
  --session-arg "amount_b_desired:u256='1000000000'" \
  --session-arg "amount_a_min:u256='9500000000000'" \
  --session-arg "amount_b_min:u256='950000000'" \
  --session-arg "to:key='account-hash-YOUR_ACCOUNT_HASH'" \
  --session-arg "deadline:u64='<UNIX_SECONDS_IN_FUTURE>'"
```

#### 6.3 Add Liquidity to Other Pools
Repeat the liquidity addition process for all trading pairs:
- CSPR/ECTO
- CSPR/ETH
- CSPR/BTC
- USDC/ECTO
- USDC/ETH
- USDC/BTC

---

## Phase 7: Verification & Testing

#### 7.1 Verify Pair Creation
Odra stores module state in the contract dictionary named `state`, not as a plain named key path.

Practical verification approach:
- Read `Factory.all_pairs_length` from the Odra `state` dictionary using `tools/odra-state-reader-ts` (see `LOCAL_NCTL_BUILD_DEPLOY_READ.md`).
- Or submit a transaction to call a view entrypoint (costs gas).

#### 7.2 Monitor Token Actions via CSPR.cloud
Use the Streaming API to monitor fungible token actions:
```bash
wscat -c 'wss://streaming.testnet.cspr.cloud/ft-token-actions' \
  -H 'authorization: YOUR_API_KEY'
```

#### 7.3 Test Swap Functionality
Execute a test swap:
```bash
casper-client put-transaction package \
  --node-address http://YOUR_NODE_HOST:7777 \
  --chain-name casper-test \
  --secret-key ./keys/secret_key.pem \
  --payment-amount 30000000000 \
  --gas-price-tolerance 1 \
  --standard-payment true \
  --contract-package-hash hash-ROUTER_PACKAGE_HASH \
  --session-entry-point swap_exact_tokens_for_tokens \
  --session-args-json '[
    {"name":"amount_in","type":"U256","value":"1000000000"},
    {"name":"amount_out_min","type":"U256","value":"900000"},
    {"name":"path","type":{"List":"Key"},"value":["hash-WCSPR_PACKAGE_HASH","hash-USDC_PACKAGE_HASH"]},
    {"name":"to","type":"Key","value":"account-hash-YOUR_ACCOUNT_HASH"},
    {"name":"deadline","type":"U64","value":<UNIX_SECONDS_IN_FUTURE>}
  ]'
```

#### 7.4 Verify Reserves
Check pair reserves via CSPR.cloud REST API:
```bash
curl -X GET 'https://api.testnet.cspr.cloud/contracts/PAIR_CONTRACT_HASH' \
  -H 'Authorization: YOUR_API_KEY'
```

---

## Phase 8: Monitoring & Maintenance

#### 8.1 Set Up Real-time Monitoring
Use CSPR.cloud Streaming API for real-time updates:

**Account Balance Monitoring:**
```javascript
const WebSocket = require('ws');
const ws = new WebSocket(
  'wss://streaming.testnet.cspr.cloud/account-balances?account_hashes=YOUR_ACCOUNT_HASH',
  { headers: { 'authorization': 'YOUR_API_KEY' } }
);

ws.on('message', (data) => {
  console.log('Balance update:', JSON.parse(data));
});
```

**Deploy Monitoring:**
```javascript
const ws = new WebSocket(
  'wss://streaming.testnet.cspr.cloud/deploys',
  { headers: { 'authorization': 'YOUR_API_KEY' } }
);

ws.on('message', (data) => {
  const deploy = JSON.parse(data);
  if (deploy.data.contract_hash === 'ROUTER_CONTRACT_HASH') {
    console.log('DEX activity:', deploy);
  }
});
```

#### 8.2 SDK Integration (JavaScript)
```javascript
import { HttpHandler, RpcClient } from 'casper-js-sdk';

const rpcHandler = new HttpHandler("https://node.testnet.cspr.cloud/rpc");
rpcHandler.setCustomHeaders({
  "Authorization": "YOUR_API_KEY"
});

const rpcClient = new RpcClient(rpcHandler);

// Get deploy status
async function checkDeploy(deployHash) {
  const deploy = await rpcClient.getTransactionByTransactionHash(deployHash);
  console.log({ deploy });
}
```

---

## 📊 Contract Address Registry

After deployment, record all contract addresses:

| Contract | Type | Hash | Package Hash |
|----------|------|------|--------------|
| Factory | DEX Core | `hash-...` | `hash-...` |
| Router | DEX Core | `hash-...` | `hash-...` |
| WCSPR | Token | `hash-...` | `hash-...` |
| USDC | Token | `hash-...` | `hash-...` |
| ECTO | Token | `hash-...` | `hash-...` |
| WETH | Token | `hash-...` | `hash-...` |
| WBTC | Token | `hash-...` | `hash-...` |
| CSPR/USDC Pair | LP | `hash-...` | `hash-...` |
| CSPR/ECTO Pair | LP | `hash-...` | `hash-...` |
| CSPR/ETH Pair | LP | `hash-...` | `hash-...` |
| CSPR/BTC Pair | LP | `hash-...` | `hash-...` |
| USDC/ECTO Pair | LP | `hash-...` | `hash-...` |
| USDC/ETH Pair | LP | `hash-...` | `hash-...` |
| USDC/BTC Pair | LP | `hash-...` | `hash-...` |

---

## 💰 Estimated Gas Costs (Testnet)

| Operation | Estimated Cost (CSPR) |
|-----------|----------------------|
| Token Deployment | 150 CSPR |
| Factory Deployment | 200 CSPR |
| Router Deployment | 200 CSPR |
| Create Pair | 100 CSPR |
| Add Liquidity | 50 CSPR |
| Swap | 30 CSPR |
| Token Approval | 5 CSPR |

**Total Estimated for Full Deployment:** ~1,500 CSPR

---

## 🔐 Security Checklist

- [ ] Private keys stored securely (never committed to git)
- [ ] API keys rotated regularly
- [ ] Contract ownership verified
- [ ] Fee recipient address configured correctly
- [ ] Slippage protection tested
- [ ] Reentrancy protection verified
- [ ] All token approvals use exact amounts needed
- [ ] Deadline parameters set appropriately

---

## 🚨 Troubleshooting

### Common Issues

1. **Deploy Failed - Out of Gas**
   - Increase `--payment-amount` parameter
   - Check current gas prices via CSPR.cloud

2. **Contract Not Found**
   - Wait for block finalization (~2 minutes)
   - Verify deploy hash status via API

3. **Insufficient Balance**
   - Request more testnet CSPR from faucet
   - Check balance via CSPR.cloud API

4. **Invalid Arguments**
   - Verify argument types match contract expectations
   - Check hex encoding for addresses

### Useful CSPR.cloud API Queries

```bash
# Get deploy status
curl -X GET 'https://api.testnet.cspr.cloud/deploys/DEPLOY_HASH' \
  -H 'Authorization: YOUR_API_KEY'

# Get contract info
curl -X GET 'https://api.testnet.cspr.cloud/contracts/CONTRACT_HASH' \
  -H 'Authorization: YOUR_API_KEY'

# Get account info
curl -X GET 'https://api.testnet.cspr.cloud/accounts/ACCOUNT_HASH' \
  -H 'Authorization: YOUR_API_KEY'

# Get fungible token actions
curl -X GET 'https://api.testnet.cspr.cloud/ft-token-actions?contract_package_hash=TOKEN_PACKAGE_HASH' \
  -H 'Authorization: YOUR_API_KEY'
```

---

## 📚 Resources

- [CSPR.cloud Documentation](https://docs.cspr.cloud/)
- [CSPR.cloud REST API](https://docs.cspr.cloud/rest-api)
- [CSPR.cloud Streaming API](https://docs.cspr.cloud/streaming-api)
- [Casper Network Documentation](https://docs.casper.network/)
- [CEP-18 Token Standard](https://github.com/casper-ecosystem/cep18)
- [Odra Framework](https://odra.dev/)
- [Casper Testnet Faucet](https://testnet.cspr.live/tools/faucet)

---

## ✅ Deployment Checklist Summary

### Pre-Deployment
- [ ] CSPR.cloud API key obtained
- [ ] Deployment wallet created and funded
- [ ] Build environment configured
- [ ] Contracts compiled successfully

### Token Deployment
- [ ] ECTO token deployed
- [ ] USDC token deployed
- [ ] WETH token deployed
- [ ] WBTC token deployed
- [ ] WCSPR token deployed

### DEX Core Deployment
- [ ] Factory contract deployed
- [ ] Router contract deployed

### Pair Creation
- [ ] CSPR/USDC pair created
- [ ] CSPR/ECTO pair created
- [ ] CSPR/ETH pair created
- [ ] CSPR/BTC pair created
- [ ] USDC/ECTO pair created
- [ ] USDC/ETH pair created
- [ ] USDC/BTC pair created

### Liquidity & Testing
- [ ] Token approvals completed
- [ ] Initial liquidity added to all pairs
- [ ] Test swaps executed successfully
- [ ] Monitoring configured

### Post-Deployment
- [ ] All contract addresses documented
- [ ] Frontend configured with contract addresses
- [ ] Security audit completed
- [ ] Documentation updated