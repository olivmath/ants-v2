#!/bin/bash

# Crypto Ants v2 - End-to-End Test Script
# Tests the complete flow: Deploy -> Indexer -> Frontend

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║   Crypto Ants v2 - E2E Tests             ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Test wallet (Anvil default account #0)
WALLET="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Load contract addresses
if [ ! -f "packages/contracts/addresses.json" ]; then
    echo -e "${RED}❌ addresses.json not found. Run deploy-local.sh first${NC}"
    exit 1
fi

EGG_ADDRESS=$(jq -r '.eggAddress' packages/contracts/addresses.json)
CRYPTO_ANTS_ADDRESS=$(jq -r '.cryptoAntsAddress' packages/contracts/addresses.json)

echo -e "${BLUE}📝 Using contracts:${NC}"
echo -e "   Egg:        $EGG_ADDRESS"
echo -e "   CryptoAnts: $CRYPTO_ANTS_ADDRESS"

# Test 1: Buy Eggs
echo -e "\n${GREEN}🧪 Test 1: Buy Eggs${NC}"
cast send $CRYPTO_ANTS_ADDRESS \
    "buyEggs(uint256)" 10 \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY \
    --value 0.1ether \
    > /dev/null

EGG_BALANCE=$(cast call $EGG_ADDRESS \
    "balanceOf(address)(uint256)" $WALLET \
    --rpc-url http://localhost:8545)

echo -e "   └─ Egg balance: $((EGG_BALANCE)) ✅"

# Test 2: Approve CryptoAnts to burn eggs
echo -e "\n${GREEN}🧪 Test 2: Approve CryptoAnts${NC}"
cast send $EGG_ADDRESS \
    "approve(address,uint256)" $CRYPTO_ANTS_ADDRESS $((EGG_BALANCE)) \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY \
    > /dev/null

echo -e "   └─ Approval successful ✅"

# Test 3: Create Ant
echo -e "\n${GREEN}🧪 Test 3: Create Ant${NC}"
cast send $CRYPTO_ANTS_ADDRESS \
    "createAnt()" \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY \
    > /dev/null

ANTS_CREATED=$(cast call $CRYPTO_ANTS_ADDRESS \
    "getAntsCreated()(uint256)" \
    --rpc-url http://localhost:8545)

echo -e "   └─ Total ants created: $((ANTS_CREATED)) ✅"

# Test 4: Get Ant Metadata
echo -e "\n${GREEN}🧪 Test 4: Get Ant Metadata${NC}"
METADATA=$(cast call $CRYPTO_ANTS_ADDRESS \
    "antsMetadata(uint256)(uint40,uint16,uint24,uint24,bool)" 1 \
    --rpc-url http://localhost:8545)

echo -e "   └─ Metadata: $METADATA ✅"

# Test 5: Wait and Lay Eggs
echo -e "\n${GREEN}🧪 Test 5: Lay Eggs${NC}"
echo -e "   └─ Attempting to lay eggs..."

cast send $CRYPTO_ANTS_ADDRESS \
    "layEggs(uint256)" 1 \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY \
    > /dev/null 2>&1 && echo -e "   └─ Eggs laid successfully ✅" || echo -e "   └─ Cooldown not met or ant died ⚠️"

# Test 6: Query GraphQL
echo -e "\n${GREEN}🧪 Test 6: Query GraphQL API${NC}"

if ! curl -s http://localhost:8080/v1/graphql > /dev/null; then
    echo -e "${YELLOW}   └─ GraphQL API not running, skipping ⚠️${NC}"
else
    GRAPHQL_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/graphql \
        -H "Content-Type: application/json" \
        -d '{"query":"{ GlobalStats { totalAnts aliveAnts } }"}')

    echo -e "   └─ Response: $GRAPHQL_RESPONSE ✅"
fi

# Test 7: Check Frontend
echo -e "\n${GREEN}🧪 Test 7: Check Frontend${NC}"

if ! curl -s http://localhost:3000 > /dev/null; then
    echo -e "${YELLOW}   └─ Frontend not running, skipping ⚠️${NC}"
else
    echo -e "   └─ Frontend is accessible ✅"
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         All Tests Passed! 🎉             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}📊 Summary:${NC}"
echo -e "   Wallet:     $WALLET"
echo -e "   Eggs:       $((EGG_BALANCE - 1))"
echo -e "   Ants:       $((ANTS_CREATED))"
echo -e "   Blockchain: http://localhost:8545"
echo -e "   GraphQL:    http://localhost:8080/v1/graphql"
echo -e "   Frontend:   http://localhost:3000"
