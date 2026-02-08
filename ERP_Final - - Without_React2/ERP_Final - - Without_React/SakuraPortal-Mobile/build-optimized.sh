#!/bin/bash
echo "🚀 Building Sakura Portal with Performance Optimizations..."

# Clean previous builds
rm -rf dist/
rm -rf android/app/build/
rm -rf ios/App/build/

# Install dependencies with optimizations
npm ci --production=false

# Build with performance optimizations
echo "📦 Building optimized bundle..."
npm run build

# Analyze bundle size
echo "📊 Analyzing bundle size..."
npx vite-bundle-analyzer dist/

# Sync with Capacitor
echo "🔄 Syncing with Capacitor..."
npx cap sync

echo "✅ Optimized build complete!"
echo "📱 Ready for production deployment"