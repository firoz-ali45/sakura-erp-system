#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

console.log('🚀 Preparing Sakura Portal for Production Deployment...\n');

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// Production configuration
const PRODUCTION_CONFIG = {
    appName: 'Sakura Portal',
    appId: 'com.sakura.portal',
    version: '1.0.0',
    description: 'Complete ERP Management System for Sakura Cafe - Accounts Payable, Forecasting, Warehouse Management',
    shortDescription: 'ERP Management System for Sakura Cafe',
    category: 'BUSINESS',
    contentRating: 'EVERYONE',
    keywords: ['erp', 'business', 'management', 'sakura', 'cafe', 'accounting', 'inventory'],
    screenshots: {
        phone: ['screenshot1.png', 'screenshot2.png', 'screenshot3.png'],
        tablet: ['screenshot_tablet1.png', 'screenshot_tablet2.png']
    }
};

// Update package.json version
function updatePackageVersion() {
    log('📦 Updating package.json version...', 'blue');
    
    const packagePath = 'package.json';
    if (fs.existsSync(packagePath)) {
        const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
        packageJson.version = PRODUCTION_CONFIG.version;
        fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2));
        log('✅ Package version updated', 'green');
    }
}

// Update Capacitor config
function updateCapacitorConfig() {
    log('⚙️  Updating Capacitor configuration...', 'blue');
    
    const configPath = 'capacitor.config.ts';
    if (fs.existsSync(configPath)) {
        let config = fs.readFileSync(configPath, 'utf8');
        
        // Update app ID and name
        config = config.replace(/appId:\s*'[^']*'/, `appId: '${PRODUCTION_CONFIG.appId}'`);
        config = config.replace(/appName:\s*'[^']*'/, `appName: '${PRODUCTION_CONFIG.appName}'`);
        
        fs.writeFileSync(configPath, config);
        log('✅ Capacitor config updated', 'green');
    }
}

// Update manifest.json
function updateManifest() {
    log('📱 Updating PWA manifest...', 'blue');
    
    const manifestPath = 'manifest.json';
    if (fs.existsSync(manifestPath)) {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
        
        manifest.name = PRODUCTION_CONFIG.appName;
        manifest.short_name = PRODUCTION_CONFIG.appName.split(' ')[0];
        manifest.description = PRODUCTION_CONFIG.description;
        
        fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
        log('✅ Manifest updated', 'green');
    }
}

// Create app store assets structure
function createAssetsStructure() {
    log('📁 Creating app store assets structure...', 'blue');
    
    const directories = [
        'store-assets/android',
        'store-assets/ios',
        'store-assets/shared',
        'store-assets/screenshots/phone',
        'store-assets/screenshots/tablet',
        'store-assets/icons'
    ];
    
    directories.forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
            log(`✅ Created directory: ${dir}`, 'green');
        }
    });
}

// Create app store listing templates
function createListingTemplates() {
    log('📝 Creating app store listing templates...', 'blue');
    
    // Google Play Store listing
    const playStoreListing = {
        title: PRODUCTION_CONFIG.appName,
        short_description: PRODUCTION_CONFIG.shortDescription,
        full_description: `🎯 **Complete ERP Management System for Sakura Cafe**

📊 **Key Features:**
• Accounts Payable Management
• Raw Materials Forecasting & Budgeting
• Warehouse & Inventory Management
• Real-time Data Synchronization
• Offline Support
• Mobile-First Design

🏢 **Perfect for:**
• Restaurant & Cafe Management
• Small to Medium Businesses
• Inventory Control
• Financial Management
• Supply Chain Operations

✨ **Why Choose Sakura Portal?**
• User-friendly interface
• Real-time updates
• Secure data handling
• Cross-platform compatibility
• Professional reporting

📱 **System Requirements:**
• Android 5.0+ (API level 21)
• iOS 12.0+
• Internet connection for data sync
• 100MB free storage space

🔒 **Privacy & Security:**
• Data encryption
• Secure authentication
• GDPR compliant
• Regular security updates

Download Sakura Portal today and transform your business operations!`,
        category: PRODUCTION_CONFIG.category,
        content_rating: PRODUCTION_CONFIG.contentRating,
        keywords: PRODUCTION_CONFIG.keywords.join(', '),
        contact_email: 'support@sakuraportal.com',
        website: 'https://sakuraportal.com',
        privacy_policy: 'https://sakuraportal.com/privacy',
        support_url: 'https://sakuraportal.com/support'
    };
    
    fs.writeFileSync('store-assets/android/play-store-listing.json', 
        JSON.stringify(playStoreListing, null, 2));
    
    // Apple App Store listing
    const appStoreListing = {
        name: PRODUCTION_CONFIG.appName,
        subtitle: 'ERP Management System',
        description: `Complete ERP Management System for Sakura Cafe

Key Features:
• Accounts Payable Management
• Raw Materials Forecasting & Budgeting  
• Warehouse & Inventory Management
• Real-time Data Synchronization
• Offline Support
• Mobile-First Design

Perfect for Restaurant & Cafe Management, Small to Medium Businesses, Inventory Control, Financial Management, and Supply Chain Operations.

Why Choose Sakura Portal?
• User-friendly interface
• Real-time updates
• Secure data handling
• Cross-platform compatibility
• Professional reporting

System Requirements:
• iOS 12.0+
• iPhone 6s or newer
• iPad Air 2 or newer
• 100MB free storage space

Privacy & Security:
• Data encryption
• Secure authentication
• GDPR compliant
• Regular security updates

Download Sakura Portal today and transform your business operations!`,
        keywords: PRODUCTION_CONFIG.keywords.join(','),
        category_primary: 'BUSINESS',
        category_secondary: 'PRODUCTIVITY',
        age_rating: '4+',
        contact_email: 'support@sakuraportal.com',
        marketing_url: 'https://sakuraportal.com',
        privacy_policy_url: 'https://sakuraportal.com/privacy',
        support_url: 'https://sakuraportal.com/support'
    };
    
    fs.writeFileSync('store-assets/ios/app-store-listing.json', 
        JSON.stringify(appStoreListing, null, 2));
    
    log('✅ App store listing templates created', 'green');
}

// Create build scripts
function createBuildScripts() {
    log('🔨 Creating production build scripts...', 'blue');
    
    // Android build script
    const androidBuildScript = `#!/bin/bash
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
echo "📋 Upload the AAB file to Google Play Console"`;

    fs.writeFileSync('store-assets/android/build-android.sh', androidBuildScript);
    
    // iOS build script
    const iosBuildScript = `#!/bin/bash
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
echo "📋 Upload to App Store Connect"`;

    fs.writeFileSync('store-assets/ios/build-ios.sh', iosBuildScript);
    
    log('✅ Build scripts created', 'green');
}

// Create privacy policy template
function createPrivacyPolicy() {
    log('📄 Creating privacy policy template...', 'blue');
    
    const privacyPolicy = `# Privacy Policy for Sakura Portal

**Last updated: ${new Date().toLocaleDateString()}**

## Information We Collect

Sakura Portal collects and processes the following types of information:

### Business Data
- Financial records and transactions
- Inventory and warehouse data
- Supplier and vendor information
- Forecasting and budgeting data

### Device Information
- Device type and operating system
- App usage statistics
- Error logs and performance data

### Account Information
- User credentials and authentication data
- Contact information for support

## How We Use Your Information

We use the collected information to:
- Provide ERP management services
- Sync data across devices
- Improve app performance and features
- Provide customer support
- Ensure data security and integrity

## Data Storage and Security

- All data is encrypted in transit and at rest
- Data is stored securely on Google Cloud Platform
- Regular security audits and updates
- Access controls and authentication required

## Data Sharing

We do not sell or share your business data with third parties except:
- As required by law
- With your explicit consent
- To provide essential services (Google Sheets integration)

## Your Rights

You have the right to:
- Access your data
- Correct inaccurate information
- Delete your account and data
- Export your data
- Withdraw consent

## Contact Us

For privacy-related questions, contact us at:
Email: privacy@sakuraportal.com
Address: [Your Company Address]

## Changes to This Policy

We may update this privacy policy. We will notify you of any changes by posting the new policy on this page.`;

    fs.writeFileSync('store-assets/shared/privacy-policy.md', privacyPolicy);
    log('✅ Privacy policy template created', 'green');
}

// Main function
async function main() {
    try {
        updatePackageVersion();
        updateCapacitorConfig();
        updateManifest();
        createAssetsStructure();
        createListingTemplates();
        createBuildScripts();
        createPrivacyPolicy();
        
        log('\n🎉 Production preparation completed!', 'green');
        log('\n📋 Next steps:', 'cyan');
        log('1. Review and customize the app store listings', 'cyan');
        log('2. Create actual screenshots and app icons', 'cyan');
        log('3. Set up developer accounts (Google Play Console & Apple Developer)', 'cyan');
        log('4. Run build scripts to create production apps', 'cyan');
        log('5. Upload to app stores', 'cyan');
        
    } catch (error) {
        log(`\n❌ Error: ${error.message}`, 'red');
        process.exit(1);
    }
}

main();







