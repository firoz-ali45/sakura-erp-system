# Sakura Portal Mobile App

A comprehensive ERP management system for Sakura Cafe, converted into a mobile app for Android and iOS platforms.

## 🌟 Features

- **Accounts Payable Management** - Track supplier payments and outstanding dues
- **Forecasting & Budgeting** - Raw materials forecasting and budget analysis
- **Warehouse Management** - Inventory and warehouse operations
- **Real-time Data Sync** - Live data updates from Google Sheets
- **Offline Support** - Works without internet connection
- **Mobile-First Design** - Optimized for mobile devices
- **PWA Support** - Installable as a Progressive Web App
- **Native App** - Full native app experience with Capacitor

## 📱 Supported Platforms

- **Android** - APK and Google Play Store ready
- **iOS** - App Store ready
- **Web** - Progressive Web App (PWA)
- **Desktop** - Electron app support

## 🚀 Quick Start

### Prerequisites

- Node.js 16+ and npm
- For Android: Android Studio and Android SDK
- For iOS: Xcode (macOS only)

### Installation

1. **Clone and install dependencies:**
   ```bash
   cd SakuraPortal-Mobile
   npm install
   ```

2. **Configure your data source:**
   - Edit `app.js` and update the `CONFIG.dataSource` URL with your Google Apps Script URL
   - Make sure your Google Apps Script is deployed as a web app

3. **Build the app:**
   ```bash
   # Build web version
   npm run build
   
   # Build for Android
   npm run build android
   
   # Build for iOS
   npm run build ios
   
   # Create Android APK
   npm run build apk
   ```

## 🛠️ Development

### Project Structure

```
SakuraPortal-Mobile/
├── index.html              # Main app HTML
├── app.js                  # Main JavaScript application
├── styles.css              # Mobile-optimized CSS
├── manifest.json           # PWA manifest
├── sw.js                   # Service worker for offline support
├── capacitor.config.ts     # Capacitor configuration
├── package.json            # Dependencies and scripts
├── build.js                # Build script
└── assets/
    ├── icons/              # App icons
    └── screenshots/        # App screenshots
```

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build web app
- `npm run build android` - Build for Android
- `npm run build ios` - Build for iOS
- `npm run build apk` - Create Android APK
- `npm run sync` - Sync with Capacitor

## 📦 Building for Distribution

### Android APK

1. **Build the APK:**
   ```bash
   npm run build apk
   ```

2. **Install on device:**
   ```bash
   adb install android/app/build/outputs/apk/debug/app-debug.apk
   ```

3. **For Google Play Store:**
   - Use Android Studio to generate signed APK
   - Follow Google Play Console guidelines

### iOS App

1. **Build for iOS:**
   ```bash
   npm run build ios
   ```

2. **Open in Xcode:**
   ```bash
   npx cap open ios
   ```

3. **Configure signing and build for App Store**

## 🔧 Configuration

### Data Source Setup

1. **Update Google Apps Script URL in `app.js`:**
   ```javascript
   const CONFIG = {
       dataSource: 'https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec',
       // ... other config
   };
   ```

2. **Deploy your Google Apps Script as a web app:**
   - Open your Google Apps Script project
   - Go to Deploy > New Deployment
   - Choose "Web app" as type
   - Set access to "Anyone"
   - Copy the web app URL

### App Customization

- **App Name:** Edit `capacitor.config.ts` and `manifest.json`
- **Colors:** Update CSS variables in `styles.css`
- **Icons:** Replace icons in `assets/icons/`
- **Features:** Modify `app.js` for functionality changes

## 📱 Installation Methods

### Method 1: Direct APK Installation (Android)

1. Build the APK: `npm run build apk`
2. Transfer APK to Android device
3. Enable "Install from Unknown Sources" in device settings
4. Install the APK file

### Method 2: PWA Installation

1. Deploy the web app to a hosting service
2. Visit the URL on mobile browser
3. Tap "Add to Home Screen" when prompted
4. App will be installed as PWA

### Method 3: App Store Distribution

1. Build and test the app
2. Create developer accounts (Google Play Console / Apple App Store Connect)
3. Submit for review
4. Publish when approved

## 🔒 Security Considerations

- **HTTPS Required:** All data sources must use HTTPS
- **API Keys:** Store sensitive keys securely
- **Data Validation:** Validate all incoming data
- **Authentication:** Implement proper user authentication if needed

## 🚀 Deployment Options

### Option 1: Web Hosting (PWA)

Deploy to any web hosting service:
- Netlify
- Vercel
- GitHub Pages
- Firebase Hosting

### Option 2: App Stores

- **Google Play Store:** For Android devices
- **Apple App Store:** For iOS devices
- **Microsoft Store:** For Windows devices

### Option 3: Enterprise Distribution

- **Android:** Direct APK distribution
- **iOS:** Apple Business Manager
- **MDM Solutions:** Mobile Device Management

## 📊 Performance Optimization

- **Lazy Loading:** Load modules only when needed
- **Caching:** Implement aggressive caching strategies
- **Compression:** Use gzip compression for assets
- **CDN:** Use Content Delivery Network for static assets

## 🔧 Troubleshooting

### Common Issues

1. **Build Failures:**
   - Ensure all dependencies are installed
   - Check Node.js version compatibility
   - Verify platform-specific tools (Android Studio, Xcode)

2. **Data Loading Issues:**
   - Verify Google Apps Script URL is correct
   - Check CORS settings
   - Ensure web app is deployed publicly

3. **App Installation Issues:**
   - Check device compatibility
   - Verify signing certificates
   - Ensure proper permissions

### Getting Help

- Check the console for error messages
- Verify all configuration settings
- Test with different devices/browsers
- Review platform-specific documentation

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

---

**Sakura Portal Mobile App** - Bringing ERP management to your mobile device! 📱✨

