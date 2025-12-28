#!/bin/bash

# Ectoplasm DEX Deployment Script for Casper Testnet
# This script automates the deployment of the DEX contracts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Ectoplasm DEX Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Load environment variables from .env file
if [ -f .env ]; then
    echo -e "${BLUE}Loading configuration from .env file...${NC}"
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and configure your settings:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Validate required environment variables
validate_env() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ] || [ "$var_value" == "your-api-key-here" ] || [ "$var_value" == "your-account-hash-here" ]; then
        echo -e "${RED}Error: $var_name is not configured in .env${NC}"
        return 1
    fi
    return 0
}

echo -e "\n${YELLOW}Validating configuration...${NC}"

VALIDATION_FAILED=0
validate_env "CSPR_CLOUD_API_KEY" || VALIDATION_FAILED=1
validate_env "CHAIN_NAME" || VALIDATION_FAILED=1
validate_env "NODE_ADDRESS" || VALIDATION_FAILED=1
validate_env "SECRET_KEY_PATH" || VALIDATION_FAILED=1
validate_env "DEPLOYER_ACCOUNT_HASH" || VALIDATION_FAILED=1

if [ $VALIDATION_FAILED -eq 1 ]; then
    echo -e "${RED}Please configure all required variables in .env${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration validated!${NC}"
echo "  Network: $CHAIN_NAME"
echo "  Node: $NODE_ADDRESS"

# Use configured values
API_KEY="$CSPR_CLOUD_API_KEY"
SECRET_KEY="$SECRET_KEY_PATH"
# DEPLOYER_ACCOUNT_HASH is actually the public key in this config
DEPLOYER_PUBLIC_KEY="$DEPLOYER_ACCOUNT_HASH"

# Gas amounts (use defaults if not set)
# Odra contracts require significant gas - 500 CSPR for tokens, 1000+ for Factory/Router
GAS_TOKEN=${GAS_TOKEN_DEPLOY:-500000000000}
GAS_FACTORY=${GAS_FACTORY_DEPLOY:-1000000000000}
GAS_ROUTER=${GAS_ROUTER_DEPLOY:-1000000000000}
GAS_PAIR=${GAS_CREATE_PAIR:-200000000000}
GAS_LIQUIDITY=${GAS_ADD_LIQUIDITY:-100000000000}
GAS_SWAP_AMOUNT=${GAS_SWAP:-50000000000}
GAS_APPROVE_AMOUNT=${GAS_APPROVE:-10000000000}

# Contract hashes (to be filled after deployment)
FACTORY_HASH=""
ROUTER_HASH=""
WCSPR_HASH=""
USDC_HASH=""
ECTO_HASH=""
WETH_HASH=""
WBTC_HASH=""

# Function to check deploy status
check_deploy() {
    local deploy_hash=$1
    echo -e "${YELLOW}Checking deploy status: $deploy_hash${NC}"
    
    for i in {1..30}; do
        response=$(curl -s -X GET "https://api.testnet.cspr.cloud/deploys/$deploy_hash" \
            -H "Authorization: $API_KEY")
        
        status=$(echo $response | jq -r '.data.status // empty')
        
        if [ "$status" == "processed" ]; then
            echo -e "${GREEN}Deploy successful!${NC}"
            return 0
        elif [ "$status" == "expired" ]; then
            echo -e "${RED}Deploy expired!${NC}"
            return 1
        fi
        
        echo "Waiting for deploy... (attempt $i/30)"
        sleep 10
    done
    
    echo -e "${RED}Deploy timeout!${NC}"
    return 1
}

# Function to get contract hash from account named keys
get_contract_hash() {
    local key_name=$1
    response=$(casper-client get-account-info \
        --node-address "$NODE_ADDRESS" \
        --public-key "$DEPLOYER_PUBLIC_KEY" \
        2>&1 | grep -v "^#")
    echo "$response" | jq -r ".result.account.named_keys[] | select(.name == \"$key_name\") | .key" | sed 's/hash-//'
}

# Function to update .env file with contract hash
update_env() {
    local key=$1
    local value=$2

    if grep -q "^$key=" .env; then
        # macOS compatible sed (use '' for in-place edit)
        sed -i '' "s|^$key=.*|$key=$value|" .env
    else
        echo "$key=$value" >> .env
    fi
}

# Step 1: Check prerequisites
echo -e "\n${YELLOW}Step 1: Checking prerequisites...${NC}"

if [ ! -f "$SECRET_KEY" ]; then
    echo -e "${RED}Error: Secret key not found at $SECRET_KEY${NC}"
    echo "Run: casper-client keygen ./keys"
    exit 1
fi

if ! command -v casper-client &> /dev/null; then
    echo -e "${RED}Error: casper-client not found${NC}"
    echo "Run: cargo install casper-client"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not found${NC}"
    echo "Install jq: sudo apt-get install jq"
    exit 1
fi

echo -e "${GREEN}Prerequisites OK${NC}"

# Step 2: Build contracts (skip if already built)
echo -e "\n${YELLOW}Step 2: Checking contracts...${NC}"
if [ -f "./wasm/EctoToken.wasm" ]; then
    echo -e "${GREEN}Contracts already built, skipping build step${NC}"
else
    echo "Building contracts..."
    # `cargo odra build` may exit non-zero if `wasm-opt` is missing,
    # even though it successfully generates WASM files.
    if cargo odra build; then
        echo -e "${GREEN}Contracts built successfully${NC}"
    else
        if [ -f "./wasm/EctoToken.wasm" ] && [ -f "./wasm/Factory.wasm" ] && [ -f "./wasm/Router.wasm" ]; then
            echo -e "${YELLOW}Warning: cargo odra build failed (likely missing wasm-opt), but WASM files exist. Continuing...${NC}"
        else
            echo -e "${RED}Error: cargo odra build failed and expected WASM files are missing.${NC}"
            echo -e "${RED}Install wasm-opt (binaryen) and retry.${NC}"
            exit 1
        fi
    fi
fi

# Step 3: Deploy tokens
echo -e "\n${YELLOW}Step 3: Deploying tokens...${NC}"

# Deploy ECTO Token (Odra-built, values hardcoded in contract)
# Odra contracts require: odra_cfg_package_hash_key_name and odra_cfg_allow_key_override
echo "Deploying ECTO Token..."
ECTO_DEPLOY=$(casper-client put-deploy \
    --node-address "$NODE_ADDRESS" \
    --chain-name "$CHAIN_NAME" \
    --secret-key "$SECRET_KEY" \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/EctoToken.wasm \
    --session-arg "odra_cfg_package_hash_key_name:string='ecto_token'" \
    --session-arg "odra_cfg_allow_key_override:bool='true'" \
    --session-arg "odra_cfg_is_upgradable:bool='false'" \
    --session-arg "odra_cfg_is_upgrade:bool='false'" \
    2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')

echo "ECTO Deploy Hash: $ECTO_DEPLOY"
check_deploy $ECTO_DEPLOY
ECTO_HASH=$(get_contract_hash "ecto_token")
echo "ECTO Contract Hash: $ECTO_HASH"
update_env "ECTO_CONTRACT_HASH" "hash-$ECTO_HASH"

# Deploy USDC Token (Odra-built, values hardcoded in contract)
echo "Deploying USDC Token..."
USDC_DEPLOY=$(casper-client put-deploy \
    --node-address "$NODE_ADDRESS" \
    --chain-name "$CHAIN_NAME" \
    --secret-key "$SECRET_KEY" \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/UsdcToken.wasm \
    --session-arg "odra_cfg_package_hash_key_name:string='usdc_token'" \
    --session-arg "odra_cfg_allow_key_override:bool='true'" \
    --session-arg "odra_cfg_is_upgradable:bool='false'" \
    --session-arg "odra_cfg_is_upgrade:bool='false'" \
    2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')

echo "USDC Deploy Hash: $USDC_DEPLOY"
check_deploy $USDC_DEPLOY
USDC_HASH=$(get_contract_hash "usdc_token")
echo "USDC Contract Hash: $USDC_HASH"
update_env "USDC_CONTRACT_HASH" "hash-$USDC_HASH"

# Deploy WETH Token (Odra-built, values hardcoded in contract)
echo "Deploying WETH Token..."
WETH_DEPLOY=$(casper-client put-deploy \
    --node-address "$NODE_ADDRESS" \
    --chain-name "$CHAIN_NAME" \
    --secret-key "$SECRET_KEY" \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/WethToken.wasm \
    --session-arg "odra_cfg_package_hash_key_name:string='weth_token'" \
    --session-arg "odra_cfg_allow_key_override:bool='true'" \
    --session-arg "odra_cfg_is_upgradable:bool='false'" \
    --session-arg "odra_cfg_is_upgrade:bool='false'" \
    2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')

echo "WETH Deploy Hash: $WETH_DEPLOY"
check_deploy $WETH_DEPLOY
WETH_HASH=$(get_contract_hash "weth_token")
echo "WETH Contract Hash: $WETH_HASH"
update_env "WETH_CONTRACT_HASH" "hash-$WETH_HASH"

# Deploy WBTC Token (Odra-built, values hardcoded in contract)
echo "Deploying WBTC Token..."
WBTC_DEPLOY=$(casper-client put-deploy \
    --node-address "$NODE_ADDRESS" \
    --chain-name "$CHAIN_NAME" \
    --secret-key "$SECRET_KEY" \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/WbtcToken.wasm \
    --session-arg "odra_cfg_package_hash_key_name:string='wbtc_token'" \
    --session-arg "odra_cfg_allow_key_override:bool='true'" \
    --session-arg "odra_cfg_is_upgradable:bool='false'" \
    --session-arg "odra_cfg_is_upgrade:bool='false'" \
    2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')

echo "WBTC Deploy Hash: $WBTC_DEPLOY"
check_deploy $WBTC_DEPLOY
WBTC_HASH=$(get_contract_hash "wbtc_token")
echo "WBTC Contract Hash: $WBTC_HASH"
update_env "WBTC_CONTRACT_HASH" "hash-$WBTC_HASH"

# NOTE: WCSPR Token skipped - no WCSPR WASM in Odra contracts
# If needed, deploy a standard CEP-18 token separately or use LpToken as WCSPR
# For now, we'll use a placeholder address for Router deployment
echo -e "${YELLOW}Skipping WCSPR deployment (not in Odra contracts)${NC}"
echo "Using LpToken contract hash as WCSPR placeholder..."
WCSPR_HASH="16eacd913f576394fbf114f652504e960367be71b560795fb9d7cf4d5c98ea68"
update_env "WCSPR_CONTRACT_HASH" "hash-$WCSPR_HASH"

# Step 4: Deploy DEX Core Contracts
echo -e "\n${YELLOW}Step 4: Deploying DEX core contracts...${NC}"

# Check if Factory is already deployed (from contracts.toml or .env)
EXISTING_FACTORY="${FACTORY_CONTRACT_HASH:-}"
if [ -n "$EXISTING_FACTORY" ] && [ "$EXISTING_FACTORY" != "your-factory-hash-here" ]; then
    echo -e "${GREEN}Factory already deployed: $EXISTING_FACTORY${NC}"
    FACTORY_HASH="${EXISTING_FACTORY#hash-}"
else
    # Deploy Factory
    echo "Deploying Factory Contract..."
    # Get the account hash from the public key
    ACCOUNT_HASH_VALUE=$(casper-client account-address --public-key "$DEPLOYER_PUBLIC_KEY" 2>&1 | grep -v "^#" | jq -r '.')
    echo "Deployer Account Hash: $ACCOUNT_HASH_VALUE"
    FACTORY_DEPLOY=$(casper-client put-deploy \
        --node-address "$NODE_ADDRESS" \
        --chain-name "$CHAIN_NAME" \
        --secret-key "$SECRET_KEY" \
        --payment-amount $GAS_FACTORY \
        --session-path ./wasm/Factory.wasm \
        --session-arg "fee_to_setter:key='$ACCOUNT_HASH_VALUE'" \
        --session-arg "odra_cfg_package_hash_key_name:string='ectoplasm_factory'" \
        --session-arg "odra_cfg_allow_key_override:bool='true'" \
        --session-arg "odra_cfg_is_upgradable:bool='false'" \
        --session-arg "odra_cfg_is_upgrade:bool='false'" \
        2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')

    echo "Factory Deploy Hash: $FACTORY_DEPLOY"
    check_deploy $FACTORY_DEPLOY
    FACTORY_HASH=$(get_contract_hash "ectoplasm_factory")
    echo "Factory Contract Hash: $FACTORY_HASH"
    update_env "FACTORY_CONTRACT_HASH" "hash-$FACTORY_HASH"
fi

# Check if Router is already deployed
EXISTING_ROUTER="${ROUTER_CONTRACT_HASH:-}"
if [ -n "$EXISTING_ROUTER" ] && [ "$EXISTING_ROUTER" != "your-router-hash-here" ]; then
    echo -e "${GREEN}Router already deployed: $EXISTING_ROUTER${NC}"
    ROUTER_HASH="${EXISTING_ROUTER#hash-}"
else
    # Deploy Router
    echo "Deploying Router Contract..."
    ROUTER_DEPLOY=$(casper-client put-deploy \
        --node-address "$NODE_ADDRESS" \
        --chain-name "$CHAIN_NAME" \
        --secret-key "$SECRET_KEY" \
        --payment-amount $GAS_ROUTER \
        --session-path ./wasm/Router.wasm \
        --session-arg "factory:key='hash-$FACTORY_HASH'" \
        --session-arg "wcspr:key='hash-$WCSPR_HASH'" \
        --session-arg "odra_cfg_package_hash_key_name:string='ectoplasm_router'" \
        --session-arg "odra_cfg_allow_key_override:bool='true'" \
        --session-arg "odra_cfg_is_upgradable:bool='false'" \
        --session-arg "odra_cfg_is_upgrade:bool='false'" \
        2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')

    echo "Router Deploy Hash: $ROUTER_DEPLOY"
    check_deploy $ROUTER_DEPLOY
    ROUTER_HASH=$(get_contract_hash "ectoplasm_router")
    echo "Router Contract Hash: $ROUTER_HASH"
    update_env "ROUTER_CONTRACT_HASH" "hash-$ROUTER_HASH"
fi

# Step 5: Create Trading Pairs
echo -e "\n${YELLOW}Step 5: Creating trading pairs...${NC}"

create_pair() {
    local token_a=$1
    local token_b=$2
    local pair_name=$3
    local env_key=$4
    
    echo "Creating $pair_name pair..."
    PAIR_DEPLOY=$(casper-client put-deploy \
        --node-address $NODE_ADDRESS \
        --chain-name $CHAIN_NAME \
        --secret-key $SECRET_KEY \
        --payment-amount $GAS_PAIR \
        --session-hash hash-$FACTORY_HASH \
        --session-entry-point "create_pair" \
        --session-arg "token_a:key='hash-$token_a'" \
        --session-arg "token_b:key='hash-$token_b'" \
        2>&1 | grep -v "^#" | jq -r '.result.deploy_hash')
    
    echo "$pair_name Deploy Hash: $PAIR_DEPLOY"
    check_deploy $PAIR_DEPLOY
    
    # Get pair address from factory (would need additional query)
    echo -e "${GREEN}$pair_name pair created!${NC}"
}

# Create all pairs
create_pair $WCSPR_HASH $USDC_HASH "CSPR/USDC" "PAIR_CSPR_USDC_HASH"
create_pair $WCSPR_HASH $ECTO_HASH "CSPR/ECTO" "PAIR_CSPR_ECTO_HASH"
create_pair $WCSPR_HASH $WETH_HASH "CSPR/ETH" "PAIR_CSPR_ETH_HASH"
create_pair $WCSPR_HASH $WBTC_HASH "CSPR/BTC" "PAIR_CSPR_BTC_HASH"
create_pair $USDC_HASH $ECTO_HASH "USDC/ECTO" "PAIR_USDC_ECTO_HASH"
create_pair $USDC_HASH $WETH_HASH "USDC/ETH" "PAIR_USDC_ETH_HASH"
create_pair $USDC_HASH $WBTC_HASH "USDC/BTC" "PAIR_USDC_BTC_HASH"

# Step 6: Save deployment info
echo -e "\n${YELLOW}Step 6: Saving deployment info...${NC}"

cat > ./deployment_info.json << EOF
{
  "network": "$CHAIN_NAME",
  "deployed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "deployer": "$ACCOUNT_HASH",
  "contracts": {
    "factory": "$FACTORY_HASH",
    "router": "$ROUTER_HASH"
  },
  "tokens": {
    "WCSPR": "$WCSPR_HASH",
    "USDC": "$USDC_HASH",
    "ECTO": "$ECTO_HASH",
    "WETH": "$WETH_HASH",
    "WBTC": "$WBTC_HASH"
  },
  "api_endpoints": {
    "rest": "https://api.testnet.cspr.cloud",
    "streaming": "wss://streaming.testnet.cspr.cloud",
    "rpc": "$NODE_ADDRESS",
    "sse": "https://node-sse.testnet.cspr.cloud"
  }
}
EOF

echo -e "${GREEN}Deployment info saved to deployment_info.json${NC}"
echo -e "${GREEN}Contract hashes updated in .env file${NC}"

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Contract Addresses:"
echo "  Factory: $FACTORY_HASH"
echo "  Router:  $ROUTER_HASH"
echo ""
echo "Token Addresses:"
echo "  WCSPR: $WCSPR_HASH"
echo "  USDC:  $USDC_HASH"
echo "  ECTO:  $ECTO_HASH"
echo "  WETH:  $WETH_HASH"
echo "  WBTC:  $WBTC_HASH"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Add initial liquidity to trading pairs"
echo "2. Configure frontend with contract addresses from .env"
echo "3. Set up monitoring via CSPR.cloud Streaming API"
echo ""
echo -e "${GREEN}Happy Trading! 🚀${NC}"