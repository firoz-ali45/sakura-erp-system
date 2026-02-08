@echo off
REM Sakura Portal - Upload to App Stores Script
REM This script automates the process of building and preparing apps for store upload

echo 🚀 Sakura Portal - App Store Upload Assistant
echo =============================================

set /p platform="Select platform (android/ios/both): "

if "%platform%"=="android" goto android
if "%platform%"=="ios" goto ios
if "%platform%"=="both" goto both
echo Invalid selection. Please choose android, ios, or both.
pause
exit /b 1

:android
echo.
echo 🤖 Preparing for Google Play Store...
echo ====================================

echo 📦 Installing dependencies...
npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

echo 📱 Building web app...
npm run build
if %errorlevel% neq 0 (
    echo ❌ Failed to build web app
    pause
    exit /b 1
)

echo 🔄 Syncing with Capacitor...
npx cap sync android
if %errorlevel% neq 0 (
    echo ❌ Failed to sync with Capacitor
    pause
    exit /b 1
)

echo 🎯 Opening Android Studio...
npx cap open android

echo.
echo ✅ Android preparation complete!
echo 📋 Next steps in Android Studio:
echo    1. Build → Generate Signed Bundle/APK
echo    2. Choose Android App Bundle
echo    3. Create or select keystore
echo    4. Build release version
echo    5. Upload AAB to Google Play Console
echo.
echo 📚 See GOOGLE_PLAY_STORE_GUIDE.md for detailed instructions
pause
goto end

:ios
echo.
echo 🍎 Preparing for Apple App Store...
echo =================================

echo 📦 Installing dependencies...
npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

echo 📱 Building web app...
npm run build
if %errorlevel% neq 0 (
    echo ❌ Failed to build web app
    pause
    exit /b 1
)

echo 🔄 Syncing with Capacitor...
npx cap sync ios
if %errorlevel% neq 0 (
    echo ❌ Failed to sync with Capacitor
    pause
    exit /b 1
)

echo 🎯 Opening Xcode...
npx cap open ios

echo.
echo ✅ iOS preparation complete!
echo 📋 Next steps in Xcode:
echo    1. Select your development team
echo    2. Set build configuration to Release
echo    3. Product → Archive
echo    4. Distribute App → App Store Connect
echo    5. Upload to App Store Connect
echo.
echo 📚 See APPLE_APP_STORE_GUIDE.md for detailed instructions
pause
goto end

:both
echo.
echo 🚀 Preparing for both platforms...
echo ================================

echo 📦 Installing dependencies...
npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

echo 📱 Building web app...
npm run build
if %errorlevel% neq 0 (
    echo ❌ Failed to build web app
    pause
    exit /b 1
)

echo 🔄 Syncing with Capacitor...
npx cap sync
if %errorlevel% neq 0 (
    echo ❌ Failed to sync with Capacitor
    pause
    exit /b 1
)

echo 🎯 Opening development environments...

echo 🤖 Opening Android Studio...
start "" "android"
timeout /t 2

echo 🍎 Opening Xcode...
start "" "ios"

echo.
echo ✅ Both platforms prepared!
echo.
echo 📋 Android Steps:
echo    1. Build → Generate Signed Bundle/APK
echo    2. Choose Android App Bundle
echo    3. Upload to Google Play Console
echo.
echo 📋 iOS Steps:
echo    1. Select development team
echo    2. Product → Archive
echo    3. Upload to App Store Connect
echo.
echo 📚 See GOOGLE_PLAY_STORE_GUIDE.md and APPLE_APP_STORE_GUIDE.md
pause
goto end

:end
echo.
echo 🎉 Upload preparation complete!
echo.
echo 📚 Documentation:
echo    - GOOGLE_PLAY_STORE_GUIDE.md
echo    - APPLE_APP_STORE_GUIDE.md
echo    - README.md
echo.
echo 📞 Need help? Check the guides above!
pause







