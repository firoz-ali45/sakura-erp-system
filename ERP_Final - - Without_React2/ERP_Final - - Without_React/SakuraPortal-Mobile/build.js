#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🚀 Building Sakura Portal Mobile App...\n');

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

function exec(command, description) {
    try {
        log(`📦 ${description}...`, 'blue');
        execSync(command, { stdio: 'inherit' });
        log(`✅ ${description} completed`, 'green');
    } catch (error) {
        log(`❌ ${description} failed: ${error.message}`, 'red');
        process.exit(1);
    }
}

// Create assets directories
function createAssetsDirectories() {
    log('📁 Creating assets directories...', 'blue');
    
    const dirs = [
        'assets/icons',
        'assets/screenshots',
        'dist'
    ];
    
    dirs.forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
            log(`✅ Created directory: ${dir}`, 'green');
        }
    });
}

// Generate app icons
function generateIcons() {
    log('🎨 Generating app icons...', 'blue');
    
    // This is a placeholder - in a real project, you would use a tool like PWA Builder
    // or manually create icons in different sizes
    const iconSizes = [16, 32, 48, 72, 96, 128, 144, 152, 192, 384, 512];
    
    iconSizes.forEach(size => {
        const iconPath = `assets/icons/icon-${size}x${size}.png`;
        if (!fs.existsSync(iconPath)) {
            // Create a simple placeholder icon
            const svgContent = `
                <svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
                    <rect width="${size}" height="${size}" fill="#284b44"/>
                    <text x="50%" y="50%" text-anchor="middle" dy=".3em" fill="white" font-family="Arial" font-size="${size * 0.3}">S</text>
                </svg>
            `;
            fs.writeFileSync(iconPath.replace('.png', '.svg'), svgContent);
            log(`✅ Created icon: ${iconPath}`, 'green');
        }
    });
}

// Build the web app
function buildWebApp() {
    log('🌐 Building web application...', 'blue');
    exec('npm run build', 'Web app build');
}

// Sync with Capacitor
function syncCapacitor() {
    log('📱 Syncing with Capacitor...', 'blue');
    exec('npx cap sync', 'Capacitor sync');
}

// Build for Android
function buildAndroid() {
    log('🤖 Building for Android...', 'blue');
    
    // Check if Android SDK is available
    try {
        execSync('adb version', { stdio: 'pipe' });
        exec('npx cap run android', 'Android build');
    } catch (error) {
        log('⚠️  Android SDK not found. Please install Android Studio and set up the Android SDK.', 'yellow');
        log('📋 Manual steps:', 'cyan');
        log('   1. Install Android Studio', 'cyan');
        log('   2. Set up Android SDK', 'cyan');
        log('   3. Run: npx cap run android', 'cyan');
    }
}

// Build for iOS
function buildiOS() {
    log('🍎 Building for iOS...', 'blue');
    
    // Check if Xcode is available (macOS only)
    if (process.platform === 'darwin') {
        try {
            execSync('xcodebuild -version', { stdio: 'pipe' });
            exec('npx cap run ios', 'iOS build');
        } catch (error) {
            log('⚠️  Xcode not found. Please install Xcode from the App Store.', 'yellow');
            log('📋 Manual steps:', 'cyan');
            log('   1. Install Xcode from App Store', 'cyan');
            log('   2. Run: npx cap run ios', 'cyan');
        }
    } else {
        log('⚠️  iOS builds are only available on macOS', 'yellow');
    }
}

// Create APK for Android
function createAPK() {
    log('📦 Creating Android APK...', 'blue');
    
    try {
        execSync('adb version', { stdio: 'pipe' });
        exec('npx cap build android', 'Android APK creation');
        
        // Find the generated APK
        const apkPath = 'android/app/build/outputs/apk/debug/app-debug.apk';
        if (fs.existsSync(apkPath)) {
            log(`✅ APK created: ${apkPath}`, 'green');
            log('📱 You can install this APK on Android devices', 'cyan');
        }
    } catch (error) {
        log('⚠️  Could not create APK. Please set up Android development environment.', 'yellow');
    }
}

// Main build function
async function main() {
    const args = process.argv.slice(2);
    const platform = args[0];
    
    log('🎯 Sakura Portal Mobile App Builder', 'bright');
    log('=====================================\n', 'bright');
    
    try {
        // Create necessary directories
        createAssetsDirectories();
        
        // Generate icons
        generateIcons();
        
        // Build web app
        buildWebApp();
        
        // Sync with Capacitor
        syncCapacitor();
        
        // Platform-specific builds
        switch (platform) {
            case 'android':
                buildAndroid();
                break;
            case 'ios':
                buildiOS();
                break;
            case 'apk':
                createAPK();
                break;
            case 'all':
                buildAndroid();
                buildiOS();
                break;
            default:
                log('📋 Available build options:', 'cyan');
                log('   npm run build android  - Build for Android', 'cyan');
                log('   npm run build ios      - Build for iOS', 'cyan');
                log('   npm run build apk      - Create Android APK', 'cyan');
                log('   npm run build all      - Build for all platforms', 'cyan');
                log('   npm run build          - Build web app only', 'cyan');
        }
        
        log('\n🎉 Build process completed!', 'green');
        log('📱 Your mobile app is ready for deployment', 'cyan');
        
    } catch (error) {
        log(`\n❌ Build failed: ${error.message}`, 'red');
        process.exit(1);
    }
}

// Run the build
main();

