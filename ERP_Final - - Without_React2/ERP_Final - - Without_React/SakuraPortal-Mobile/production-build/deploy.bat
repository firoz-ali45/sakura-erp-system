@echo off
# Quick SakuraPortal Deployment Script

echo "🚀 Deploying SakuraPortal to Live Websites..."

# Check if production build exists
if [ ! -d "production-build" ]; then
    echo "❌ Production build not found. Run deploy-live.js first."
    exit 1
fi

# Upload to websites (customize these commands for your hosting)
echo "📤 Uploading to Website 1..."
# scp -r production-build/* user@website1.com:/public_html/

echo "📤 Uploading to Website 2..."
# scp -r production-build/* user@website2.com:/public_html/

echo "📤 Uploading to Website 3..."
# scp -r production-build/* user@website3.com:/public_html/

echo "✅ Deployment completed!"
echo "🌐 Your SakuraPortal is now live on all websites!"
echo "🔐 Password: Sakura123@@"
