# 📱 Sakura Portal Mobile App - Installation Guide

This guide will help you install the Sakura Portal mobile app on your Android or iOS device.

## 🚀 Quick Installation Methods

### Method 1: Direct APK Installation (Android)

**Step 1: Enable Unknown Sources**
1. Open **Settings** on your Android device
2. Go to **Security** or **Privacy & Security**
3. Enable **"Install from Unknown Sources"** or **"Unknown Apps"**
4. Select your browser or file manager and allow installation

**Step 2: Download and Install**
1. Download the APK file from the build output
2. Open the downloaded APK file
3. Tap **"Install"** when prompted
4. Wait for installation to complete
5. Tap **"Open"** to launch the app

### Method 2: Progressive Web App (PWA) - All Platforms

**For Android:**
1. Open Chrome browser
2. Navigate to the app URL
3. Tap the **menu** (three dots) in Chrome
4. Select **"Add to Home screen"**
5. Tap **"Add"** to confirm
6. The app will appear on your home screen

**For iOS:**
1. Open Safari browser
2. Navigate to the app URL
3. Tap the **share** button (square with arrow)
4. Select **"Add to Home Screen"**
5. Tap **"Add"** to confirm
6. The app will appear on your home screen

## 🛠️ Development Installation

### Prerequisites

Before installing, ensure you have:

- **Node.js 16+** - [Download here](https://nodejs.org/)
- **npm** - Comes with Node.js
- **Git** - [Download here](https://git-scm.com/)

### For Android Development:
- **Android Studio** - [Download here](https://developer.android.com/studio)
- **Android SDK** - Installed with Android Studio
- **Java Development Kit (JDK)** - [Download here](https://adoptium.net/)

### For iOS Development (macOS only):
- **Xcode** - Available on Mac App Store
- **iOS Simulator** - Comes with Xcode
- **CocoaPods** - Install with: `sudo gem install cocoapods`

## 📦 Step-by-Step Installation

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd SakuraPortal-Mobile
```

### Step 2: Install Dependencies

```bash
npm install
```

### Step 3: Configure the App

1. **Update Data Source URL:**
   ```javascript
   // Edit app.js file
   const CONFIG = {
       dataSource: 'https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec',
       // ... other settings
   };
   ```

2. **Update App Configuration:**
   ```typescript
   // Edit capacitor.config.ts
   const config: CapacitorConfig = {
     appId: 'com.sakura.portal',
     appName: 'Sakura Portal',
     // ... other settings
   };
   ```

### Step 4: Build the App

```bash
# Build web version
npm run build

# Sync with Capacitor
npm run sync
```

### Step 5: Platform-Specific Installation

#### Android Installation

```bash
# Build for Android
npm run build android

# Or create APK directly
npm run build apk
```

**Manual Android Setup:**
1. Open Android Studio
2. Open the `android` folder in the project
3. Wait for Gradle sync to complete
4. Connect your Android device or start an emulator
5. Click **Run** button in Android Studio

#### iOS Installation (macOS only)

```bash
# Build for iOS
npm run build ios

# Open in Xcode
npx cap open ios
```

**Manual iOS Setup:**
1. Open Xcode
2. Open the `ios` folder in the project
3. Select your development team in project settings
4. Connect your iOS device or start simulator
5. Click **Run** button in Xcode

## 🔧 Configuration Options

### App Settings

You can customize the app by editing these files:

**App Identity:**
- `capacitor.config.ts` - App ID, name, and native settings
- `manifest.json` - PWA settings and icons

**Visual Customization:**
- `styles.css` - Colors, fonts, and styling
- `assets/icons/` - App icons and logos

**Functionality:**
- `app.js` - Main app logic and features
- `index.html` - App structure and layout

### Environment Configuration

Create a `.env` file for environment-specific settings:

```env
# Data source configuration
DATA_SOURCE_URL=https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec

# App configuration
APP_NAME=Sakura Portal
APP_VERSION=1.0.0

# Feature flags
ENABLE_NOTIFICATIONS=true
AUTO_REFRESH_INTERVAL=60000
```

## 📱 Device Requirements

### Android Requirements
- **Android 5.0+** (API level 21+)
- **RAM:** 2GB minimum, 4GB recommended
- **Storage:** 100MB free space
- **Network:** Internet connection for data sync

### iOS Requirements
- **iOS 12.0+**
- **iPhone:** iPhone 6s or newer
- **iPad:** iPad Air 2 or newer
- **Storage:** 100MB free space
- **Network:** Internet connection for data sync

### Web/PWA Requirements
- **Modern browser:** Chrome 70+, Safari 12+, Firefox 70+, Edge 79+
- **JavaScript enabled**
- **Storage:** 50MB for offline cache
- **Network:** Internet connection for data sync

## 🚨 Troubleshooting

### Common Installation Issues

**"App not installed" (Android):**
- Ensure Unknown Sources is enabled
- Check if device has enough storage
- Verify APK is not corrupted
- Try installing from a different source

**"Cannot install app" (iOS):**
- Ensure device meets iOS requirements
- Check if developer certificate is trusted
- Verify app is signed properly
- Try installing via Xcode

**Build failures:**
- Update Node.js to latest LTS version
- Clear npm cache: `npm cache clean --force`
- Delete node_modules and reinstall: `rm -rf node_modules && npm install`
- Check platform-specific tools are properly installed

**Data not loading:**
- Verify Google Apps Script URL is correct
- Check internet connection
- Ensure CORS is enabled in Google Apps Script
- Verify web app is deployed publicly

### Getting Help

1. **Check Console Logs:**
   - Android: Use `adb logcat` to view logs
   - iOS: Use Xcode console
   - Web: Use browser developer tools

2. **Verify Configuration:**
   - Double-check all URLs and settings
   - Ensure all dependencies are installed
   - Verify platform-specific tools are working

3. **Test on Different Devices:**
   - Try installation on different devices
   - Test with different operating system versions
   - Check browser compatibility for PWA

## 📋 Pre-Installation Checklist

Before installing, ensure:

- [ ] Device meets minimum requirements
- [ ] Sufficient storage space available
- [ ] Internet connection is stable
- [ ] Google Apps Script is deployed and accessible
- [ ] All configuration settings are correct
- [ ] Platform-specific tools are installed (for development)

## 🎯 Post-Installation Verification

After installation, verify:

- [ ] App launches successfully
- [ ] Data loads correctly
- [ ] All features work as expected
- [ ] Offline functionality works
- [ ] Notifications work (if enabled)
- [ ] App updates properly

## 📞 Support

If you encounter issues:

1. Check this troubleshooting guide
2. Review the main README.md file
3. Check console logs for error messages
4. Create an issue in the repository
5. Contact the development team

---

**Happy installing!** 🎉 Your Sakura Portal mobile app should now be ready to use.

