#!/bin/bash
echo "🚀 Deploying RM Forecasting to Surge.sh..."

# Install surge if not already installed
if ! command -v surge &> /dev/null; then
    echo "📦 Installing Surge CLI..."
    npm install -g surge
fi

# Deploy to surge.sh
echo "🌐 Deploying to https://sakura-rm-forecasting.surge.sh/..."
surge . sakura-rm-forecasting.surge.sh

echo "✅ RM Forecasting deployed successfully!"
echo "🔗 Visit: https://sakura-rm-forecasting.surge.sh/"