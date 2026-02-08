#!/bin/bash
echo "🤖 Building Sakura Portal for Google Play Store..."

# Clean previous builds
rm -rf android/app/build

# Build web app
npm run build

# Sync with Capacitor
npx cap sync android

# Open Android Studio for final build
npx cap open android

echo "✅ Android build ready for Google Play Store upload!"
echo "📱 Open Android Studio and generate signed AAB file"
echo "📋 Upload the AAB file to Google Play Console"