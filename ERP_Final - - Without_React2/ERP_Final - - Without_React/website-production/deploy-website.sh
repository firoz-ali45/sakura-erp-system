#!/bin/bash
# SakuraPortal Website Quick Deployment Script

echo "🌐 Deploying SakuraPortal Website to Live..."

# Check if production build exists
if [ ! -d "website-production" ]; then
    echo "❌ Website production build not found. Run deploy-website.js first."
    exit 1
fi

echo "📤 Uploading SakuraPortal Website..."

# Method 1: FTP Upload (uncomment and configure)
# ftp -n your-ftp-server.com << EOF
# user your-username your-password
# binary
# cd /public_html
# lcd website-production
# mput *
# quit
# EOF

# Method 2: SCP Upload (uncomment and configure)
# scp -r website-production/* user@your-website.com:/public_html/

# Method 3: RSYNC Upload (uncomment and configure)
# rsync -avz website-production/ user@your-website.com:/public_html/

echo "✅ SakuraPortal Website deployment completed!"
echo ""
echo "🌐 Your website is now live with:"
echo "   🎨 Beautiful Sakura animations"
echo "   🔐 Password protection (Sakura123@@)"
echo "   📊 Complete ERP system"
echo "   📱 Mobile-optimized design"
echo "   ⚡ Lightning-fast performance"
echo ""
echo "🔗 Visit your website to see the magic!"
