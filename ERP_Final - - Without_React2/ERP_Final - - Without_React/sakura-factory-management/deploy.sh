#!/bin/bash
echo "🚀 Deploying Factory Management to Surge.sh..."

# Install surge if not already installed
if ! command -v surge &> /dev/null; then
    echo "📦 Installing Surge CLI..."
    npm install -g surge
fi

# Deploy to surge.sh
echo "🌐 Deploying to https://sakura-factory-management.surge.sh/..."
surge . sakura-factory-management.surge.sh

echo "✅ Factory Management deployed successfully!"
echo "🔗 Visit: https://sakura-factory-management.surge.sh/"