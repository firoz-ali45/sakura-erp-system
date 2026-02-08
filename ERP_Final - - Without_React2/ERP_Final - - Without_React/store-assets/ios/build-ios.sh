#!/bin/bash
echo "🍎 Building Sakura Portal for Apple App Store..."

# Clean previous builds
rm -rf ios/App/App.xcarchive

# Build web app
npm run build

# Sync with Capacitor
npx cap sync ios

# Open Xcode for final build
npx cap open ios

echo "✅ iOS build ready for Apple App Store upload!"
echo "📱 Open Xcode and archive the app"
echo "📋 Upload to App Store Connect"