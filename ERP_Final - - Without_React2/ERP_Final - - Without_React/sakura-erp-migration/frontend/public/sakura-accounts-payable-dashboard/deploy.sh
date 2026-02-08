#!/bin/bash
echo "🚀 Deploying Accounts Payable Dashboard to Surge.sh..."

# Install surge if not already installed
if ! command -v surge &> /dev/null; then
    echo "📦 Installing Surge CLI..."
    npm install -g surge
fi

# Deploy to surge.sh
echo "🌐 Deploying to https://sakura-accounts-payable-dashboard.surge.sh/..."
surge . sakura-accounts-payable-dashboard.surge.sh

echo "✅ Accounts Payable Dashboard deployed successfully!"
echo "🔗 Visit: https://sakura-accounts-payable-dashboard.surge.sh/"