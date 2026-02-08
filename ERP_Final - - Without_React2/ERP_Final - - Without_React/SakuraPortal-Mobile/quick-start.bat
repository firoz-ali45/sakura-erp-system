@echo off
REM Sakura Portal Mobile App - Quick Start Script for Windows
REM This script will set up the mobile app project quickly

echo 🚀 Sakura Portal Mobile App - Quick Start
echo ==========================================

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed. Please install Node.js 16+ from https://nodejs.org/
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
    echo ✅ Node.js is installed: %NODE_VERSION%
)

REM Check if npm is installed
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ npm is not installed. Please install npm.
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('npm --version') do set NPM_VERSION=%%i
    echo ✅ npm is installed: %NPM_VERSION%
)

echo.
echo 📦 Creating assets directories...
if not exist "assets\icons" mkdir "assets\icons"
if not exist "assets\screenshots" mkdir "assets\screenshots"
echo ✅ Assets directories created

echo.
echo 📦 Installing dependencies...
npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
) else (
    echo ✅ Dependencies installed successfully
)

echo.
echo 📦 Building the project...
npm run build
if %errorlevel% neq 0 (
    echo ❌ Failed to build project
    pause
    exit /b 1
) else (
    echo ✅ Project built successfully
)

echo.
echo 📦 Setting up Capacitor...
npx cap sync
if %errorlevel% neq 0 (
    echo ⚠️  Capacitor setup failed. You may need to install platform-specific tools.
) else (
    echo ✅ Capacitor setup completed
)

echo.
echo ✅ Setup completed successfully!
echo.
echo 🎯 Next steps:
echo 1. Update the data source URL in app.js
echo 2. Configure your Google Apps Script
echo 3. Run 'npm run build android' for Android
echo 4. Run 'npm run build ios' for iOS (macOS only)
echo 5. Run 'npm run dev' for development
echo.
echo 📚 Documentation:
echo - README.md - Main documentation
echo - INSTALLATION.md - Installation guide
echo - DEPLOYMENT.md - Deployment guide
echo.
echo ✅ Happy coding! 🚀
pause







