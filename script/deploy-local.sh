#!/bin/bash
set -e

echo "🚀 Deploying CryptoAnts locally..."
echo ""

# Check if anvil is running
if ! nc -z localhost 8545 2>/dev/null; then
    echo "⚠️  Anvil is not running!"
    echo "Please start anvil in another terminal:"
    echo "  anvil"
    exit 1
fi

# Deploy using Foundry script
forge script script/Deploy.s.sol:Deploy \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --account ff80

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Contract addresses saved in:"
echo "   broadcast/Deploy.s.sol/31337/run-latest.json"
