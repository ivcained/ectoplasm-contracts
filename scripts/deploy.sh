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
ACCOUNT_HASH="$DEPLOYER_ACCOUNT_HASH"

# Gas amounts (use defaults if not set)
GAS_TOKEN=${GAS_TOKEN_DEPLOY:-150000000000}
GAS_FACTORY=${GAS_FACTORY_DEPLOY:-200000000000}
GAS_ROUTER=${GAS_ROUTER_DEPLOY:-200000000000}
GAS_PAIR=${GAS_CREATE_PAIR:-100000000000}
GAS_LIQUIDITY=${GAS_ADD_LIQUIDITY:-50000000000}
GAS_SWAP_AMOUNT=${GAS_SWAP:-30000000000}
GAS_APPROVE_AMOUNT=${GAS_APPROVE:-5000000000}

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

# Function to get contract hash from deploy
get_contract_hash() {
    local deploy_hash=$1
    response=$(curl -s -X GET "https://api.testnet.cspr.cloud/deploys/$deploy_hash" \
        -H "Authorization: $API_KEY")
    echo $response | jq -r '.data.contract_hash // empty'
}

# Function to update .env file with contract hash
update_env() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" .env; then
        sed -i "s|^$key=.*|$key=$value|" .env
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

# Step 2: Build contracts
echo -e "\n${YELLOW}Step 2: Building contracts...${NC}"
cargo odra build
echo -e "${GREEN}Contracts built successfully${NC}"

# Step 3: Deploy tokens
echo -e "\n${YELLOW}Step 3: Deploying tokens...${NC}"

# Deploy ECTO Token
echo "Deploying ECTO Token..."
ECTO_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/Cep18.wasm \
    --session-arg "name:string='Ectoplasm Token'" \
    --session-arg "symbol:string='ECTO'" \
    --session-arg "decimals:u8='18'" \
    --session-arg "total_supply:u256='1000000000000000000000000000'" \
    | jq -r '.result.deploy_hash')

echo "ECTO Deploy Hash: $ECTO_DEPLOY"
check_deploy $ECTO_DEPLOY
ECTO_HASH=$(get_contract_hash $ECTO_DEPLOY)
echo "ECTO Contract Hash: $ECTO_HASH"
update_env "ECTO_CONTRACT_HASH" "$ECTO_HASH"

# Deploy USDC Token
echo "Deploying USDC Token..."
USDC_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/Cep18.wasm \
    --session-arg "name:string='USD Coin'" \
    --session-arg "symbol:string='USDC'" \
    --session-arg "decimals:u8='6'" \
    --session-arg "total_supply:u256='1000000000000'" \
    | jq -r '.result.deploy_hash')

echo "USDC Deploy Hash: $USDC_DEPLOY"
check_deploy $USDC_DEPLOY
USDC_HASH=$(get_contract_hash $USDC_DEPLOY)
echo "USDC Contract Hash: $USDC_HASH"
update_env "USDC_CONTRACT_HASH" "$USDC_HASH"

# Deploy WETH Token
echo "Deploying WETH Token..."
WETH_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/Cep18.wasm \
    --session-arg "name:string='Wrapped Ethereum'" \
    --session-arg "symbol:string='WETH'" \
    --session-arg "decimals:u8='18'" \
    --session-arg "total_supply:u256='100000000000000000000000'" \
    | jq -r '.result.deploy_hash')

echo "WETH Deploy Hash: $WETH_DEPLOY"
check_deploy $WETH_DEPLOY
WETH_HASH=$(get_contract_hash $WETH_DEPLOY)
echo "WETH Contract Hash: $WETH_HASH"
update_env "WETH_CONTRACT_HASH" "$WETH_HASH"

# Deploy WBTC Token
echo "Deploying WBTC Token..."
WBTC_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/Cep18.wasm \
    --session-arg "name:string='Wrapped Bitcoin'" \
    --session-arg "symbol:string='WBTC'" \
    --session-arg "decimals:u8='8'" \
    --session-arg "total_supply:u256='2100000000000000'" \
    | jq -r '.result.deploy_hash')

echo "WBTC Deploy Hash: $WBTC_DEPLOY"
check_deploy $WBTC_DEPLOY
WBTC_HASH=$(get_contract_hash $WBTC_DEPLOY)
echo "WBTC Contract Hash: $WBTC_HASH"
update_env "WBTC_CONTRACT_HASH" "$WBTC_HASH"

# Deploy WCSPR Token
echo "Deploying WCSPR Token..."
WCSPR_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_TOKEN \
    --session-path ./wasm/Cep18.wasm \
    --session-arg "name:string='Wrapped CSPR'" \
    --session-arg "symbol:string='WCSPR'" \
    --session-arg "decimals:u8='9'" \
    --session-arg "total_supply:u256='0'" \
    | jq -r '.result.deploy_hash')

echo "WCSPR Deploy Hash: $WCSPR_DEPLOY"
check_deploy $WCSPR_DEPLOY
WCSPR_HASH=$(get_contract_hash $WCSPR_DEPLOY)
echo "WCSPR Contract Hash: $WCSPR_HASH"
update_env "WCSPR_CONTRACT_HASH" "$WCSPR_HASH"

# Step 4: Deploy DEX Core Contracts
echo -e "\n${YELLOW}Step 4: Deploying DEX core contracts...${NC}"

# Deploy Factory
echo "Deploying Factory Contract..."
FACTORY_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_FACTORY \
    --session-path ./wasm/Factory.wasm \
    --session-arg "fee_to_setter:key='account-hash-$ACCOUNT_HASH'" \
    | jq -r '.result.deploy_hash')

echo "Factory Deploy Hash: $FACTORY_DEPLOY"
check_deploy $FACTORY_DEPLOY
FACTORY_HASH=$(get_contract_hash $FACTORY_DEPLOY)
echo "Factory Contract Hash: $FACTORY_HASH"
update_env "FACTORY_CONTRACT_HASH" "$FACTORY_HASH"

# Deploy Router
echo "Deploying Router Contract..."
ROUTER_DEPLOY=$(casper-client put-deploy \
    --node-address $NODE_ADDRESS \
    --chain-name $CHAIN_NAME \
    --secret-key $SECRET_KEY \
    --payment-amount $GAS_ROUTER \
    --session-path ./wasm/Router.wasm \
    --session-arg "factory:key='hash-$FACTORY_HASH'" \
    --session-arg "wcspr:key='hash-$WCSPR_HASH'" \
    | jq -r '.result.deploy_hash')

echo "Router Deploy Hash: $ROUTER_DEPLOY"
check_deploy $ROUTER_DEPLOY
ROUTER_HASH=$(get_contract_hash $ROUTER_DEPLOY)
echo "Router Contract Hash: $ROUTER_HASH"
update_env "ROUTER_CONTRACT_HASH" "$ROUTER_HASH"

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
        | jq -r '.result.deploy_hash')
    
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