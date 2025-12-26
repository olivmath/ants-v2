#!/bin/bash

# Crypto Ants v2 - Local Development Script
# This script starts all services needed for local development

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down services...${NC}"
    kill $(jobs -p) 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║   Crypto Ants v2 - Development Mode     ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
    echo -e "${RED}❌ pnpm is not installed. Please install it first:${NC}"
    echo "   npm install -g pnpm"
    exit 1
fi

# Check if Envio CLI is installed
if ! command -v envio &> /dev/null; then
    echo -e "${YELLOW}⚠️  Envio CLI not found. Installing globally...${NC}"
    npm install -g envio
fi

# Check if Foundry is installed (for anvil)
if ! command -v anvil &> /dev/null; then
    echo -e "${RED}❌ Foundry/Anvil is not installed. Please install it first:${NC}"
    echo "   curl -L https://foundry.paradigm.xyz | bash"
    echo "   foundryup"
    exit 1
fi

# Install dependencies if needed
echo -e "${BLUE}📦 Installing dependencies...${NC}"
pnpm install

# Start Anvil (local blockchain)
echo -e "${GREEN}⛓️  Starting Anvil (local blockchain)...${NC}"
cd packages/contracts
anvil --block-time 1 > anvil.log 2>&1 &
ANVIL_PID=$!
echo -e "   └─ PID: $ANVIL_PID"
sleep 3

# Deploy contracts
echo -e "${GREEN}🚀 Deploying contracts to local network...${NC}"
pnpm run deploy:local > deploy.log 2>&1 &
DEPLOY_PID=$!
wait $DEPLOY_PID

# Extract contract addresses from deploy output
if [ -f "deploy.log" ]; then
    echo -e "${BLUE}📝 Contract addresses:${NC}"
    grep -E "CryptoAnts|Egg" deploy.log || echo "   Could not extract addresses"
fi

cd ../..

# Start Envio Indexer
echo -e "${GREEN}🔍 Starting Envio Indexer...${NC}"
cd packages/indexer

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env not found in indexer. Copying from .env.example${NC}"
    cp .env.example .env
    echo -e "${RED}⚠️  Please edit packages/indexer/.env with correct values${NC}"
fi

# Run codegen
echo -e "${BLUE}   └─ Running codegen...${NC}"
pnpm run codegen > codegen.log 2>&1

# Start indexer
pnpm run dev > indexer.log 2>&1 &
INDEXER_PID=$!
echo -e "   └─ PID: $INDEXER_PID"
echo -e "   └─ GraphQL: http://localhost:8080/v1/graphql"
echo -e "   └─ Console: http://localhost:8080/console"

cd ../..

# Start Frontend
echo -e "${GREEN}🌐 Starting Frontend...${NC}"
cd packages/dapp

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo -e "${YELLOW}⚠️  .env.local not found. Copying from .env.example${NC}"
    cp .env.example .env.local
    echo -e "${RED}⚠️  Please edit packages/dapp/.env.local with correct values${NC}"
fi

pnpm run dev > frontend.log 2>&1 &
FRONTEND_PID=$!
echo -e "   └─ PID: $FRONTEND_PID"
echo -e "   └─ URL: http://localhost:3000"

cd ../..

# Print status
echo -e "\n${GREEN}✅ All services started successfully!${NC}\n"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Services Running                 ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} ⛓️  Anvil:    http://localhost:8545     ${BLUE}║${NC}"
echo -e "${BLUE}║${NC} 🔍 GraphQL:  http://localhost:8080     ${BLUE}║${NC}"
echo -e "${BLUE}║${NC} 🌐 Frontend: http://localhost:3000     ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}📋 Logs:${NC}"
echo -e "   Anvil:    tail -f packages/contracts/anvil.log"
echo -e "   Deploy:   cat packages/contracts/deploy.log"
echo -e "   Indexer:  tail -f packages/indexer/indexer.log"
echo -e "   Frontend: tail -f packages/dapp/frontend.log"

echo -e "\n${YELLOW}🛑 Press Ctrl+C to stop all services${NC}\n"

# Keep script running
wait
