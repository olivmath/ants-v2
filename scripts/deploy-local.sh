#!/bin/bash

# Crypto Ants v2 - Local Deploy Script
# Deploys contracts to local Anvil network and configures indexer

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║   Crypto Ants v2 - Local Deploy         ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Check if Anvil is running
if ! curl -s http://localhost:8545 > /dev/null; then
    echo -e "${RED}❌ Anvil is not running on port 8545${NC}"
    echo -e "   Start it with: anvil"
    exit 1
fi

echo -e "${GREEN}✅ Anvil is running${NC}"

# IPFS CID (you should update this after uploading SVG)
IPFS_GATEWAY="https://ipfs.io/ipfs/"
ANT_SVG_CID="${ANT_SVG_CID:-QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}"

if [ "$ANT_SVG_CID" = "QmXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ]; then
    echo -e "${YELLOW}⚠️  Using placeholder IPFS CID. Update ANT_SVG_CID env variable${NC}"
fi

BASE_TOKEN_URI="${IPFS_GATEWAY}${ANT_SVG_CID}"

cd packages/contracts

echo -e "${BLUE}📦 Building contracts...${NC}"
forge build

echo -e "${BLUE}🚀 Deploying Egg contract...${NC}"
EGG_DEPLOY=$(forge create src/Egg.sol:Egg \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --constructor-args "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" \
    --json)

EGG_ADDRESS=$(echo $EGG_DEPLOY | jq -r '.deployedTo')
echo -e "${GREEN}   └─ Egg deployed at: ${EGG_ADDRESS}${NC}"

echo -e "${BLUE}🚀 Deploying CryptoAnts contract...${NC}"
ANTS_DEPLOY=$(forge create src/CryptoAnts.sol:CryptoAnts \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --constructor-args "$EGG_ADDRESS" "$BASE_TOKEN_URI" \
    --json)

CRYPTO_ANTS_ADDRESS=$(echo $ANTS_DEPLOY | jq -r '.deployedTo')
echo -e "${GREEN}   └─ CryptoAnts deployed at: ${CRYPTO_ANTS_ADDRESS}${NC}"

# Save addresses to file
cat > addresses.json <<EOF
{
  "eggAddress": "$EGG_ADDRESS",
  "cryptoAntsAddress": "$CRYPTO_ANTS_ADDRESS",
  "baseTokenURI": "$BASE_TOKEN_URI",
  "network": "localhost",
  "chainId": 31337
}
EOF

echo -e "${GREEN}✅ Addresses saved to packages/contracts/addresses.json${NC}"

# Update indexer config
cd ../indexer

echo -e "${BLUE}📝 Updating indexer config...${NC}"

# Update config.yaml with deployed address
sed -i.bak "s/address:.*/address:\n          - \"$CRYPTO_ANTS_ADDRESS\"/" config.yaml
rm config.yaml.bak

echo -e "${GREEN}   └─ Updated config.yaml${NC}"

# Update .env if it exists
if [ -f ".env" ]; then
    sed -i.bak "s/CRYPTO_ANTS_ADDRESS=.*/CRYPTO_ANTS_ADDRESS=$CRYPTO_ANTS_ADDRESS/" .env
    sed -i.bak "s/EGG_ADDRESS=.*/EGG_ADDRESS=$EGG_ADDRESS/" .env
    sed -i.bak "s/ANT_SVG_CID=.*/ANT_SVG_CID=$ANT_SVG_CID/" .env
    rm .env.bak
    echo -e "${GREEN}   └─ Updated .env${NC}"
fi

# Update frontend ABIs
cd ../dapp

echo -e "${BLUE}📝 Updating frontend ABIs...${NC}"

# Update contract addresses in abis.ts
cat > src/contracts/abis.ts.new <<EOF
// Auto-generated contract addresses and ABIs
// Last updated: $(date)

export const EGG_ADDRESS = "$EGG_ADDRESS" as const;
export const CRYPTO_ANTS_ADDRESS = "$CRYPTO_ANTS_ADDRESS" as const;

$(cat src/contracts/abis.ts | grep -A 9999 "export const eggABI")
EOF

mv src/contracts/abis.ts.new src/contracts/abis.ts

echo -e "${GREEN}   └─ Updated abis.ts${NC}"

# Update .env.local
if [ -f ".env.local" ]; then
    sed -i.bak "s/NEXT_PUBLIC_ANT_SVG_CID=.*/NEXT_PUBLIC_ANT_SVG_CID=$ANT_SVG_CID/" .env.local
    rm .env.local.bak
    echo -e "${GREEN}   └─ Updated .env.local${NC}"
fi

cd ../..

echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Deploy Successful!               ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC} Egg:        $EGG_ADDRESS"
echo -e "${GREEN}║${NC} CryptoAnts: $CRYPTO_ANTS_ADDRESS"
echo -e "${GREEN}║${NC} IPFS URI:   $BASE_TOKEN_URI"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}📋 Next steps:${NC}"
echo -e "   1. Start Envio indexer: cd packages/indexer && pnpm run dev"
echo -e "   2. Start frontend: cd packages/dapp && pnpm run dev"
echo -e "   3. Or run all services: ./scripts/dev.sh"

cd packages/contracts
