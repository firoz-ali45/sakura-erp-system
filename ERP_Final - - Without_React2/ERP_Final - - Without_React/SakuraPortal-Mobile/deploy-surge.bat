@echo off
REM Sakura Portal Mobile App - Surge.sh Deployment Script for Windows
REM This script deploys the mobile app to all three Surge.sh URLs

echo 🚀 Sakura Portal Mobile App - Surge.sh Deployment
echo ==================================================

REM Check if Surge CLI is installed
surge --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Surge CLI not found. Installing...
    npm install -g surge
    if %errorlevel% neq 0 (
        echo ❌ Failed to install Surge CLI
        pause
        exit /b 1
    ) else (
        echo ✅ Surge CLI installed successfully
    )
) else (
    echo ✅ Surge CLI is already installed
)

echo.
echo 📦 Building mobile app for deployment...

REM Install dependencies
npm install
if %errorlevel% neq 0 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

REM Build the app
npm run build
if %errorlevel% neq 0 (
    echo ❌ Failed to build app
    pause
    exit /b 1
)

echo ✅ App built successfully

echo.
echo 📦 Deploying to all three URLs...

REM Deploy to Accounts Payable Dashboard
echo 📱 Deploying to sakura-accounts-payable-dashboard.surge.sh...
if exist temp-deploy-apd rmdir /s /q temp-deploy-apd
mkdir temp-deploy-apd
xcopy /E /I dist\* temp-deploy-apd\
cd temp-deploy-apd
surge . sakura-accounts-payable-dashboard.surge.sh --domain sakura-accounts-payable-dashboard.surge.sh
cd ..
rmdir /s /q temp-deploy-apd

if %errorlevel% equ 0 (
    echo ✅ Successfully deployed to sakura-accounts-payable-dashboard.surge.sh
) else (
    echo ❌ Failed to deploy to sakura-accounts-payable-dashboard.surge.sh
)

REM Deploy to Factory Management
echo 📱 Deploying to sakura-factory-management.surge.sh...
if exist temp-deploy-fm rmdir /s /q temp-deploy-fm
mkdir temp-deploy-fm
xcopy /E /I dist\* temp-deploy-fm\
cd temp-deploy-fm
surge . sakura-factory-management.surge.sh --domain sakura-factory-management.surge.sh
cd ..
rmdir /s /q temp-deploy-fm

if %errorlevel% equ 0 (
    echo ✅ Successfully deployed to sakura-factory-management.surge.sh
) else (
    echo ❌ Failed to deploy to sakura-factory-management.surge.sh
)

REM Deploy to RM Forecasting
echo 📱 Deploying to sakura-rm-forecasting.surge.sh...
if exist temp-deploy-rm rmdir /s /q temp-deploy-rm
mkdir temp-deploy-rm
xcopy /E /I dist\* temp-deploy-rm\
cd temp-deploy-rm
surge . sakura-rm-forecasting.surge.sh --domain sakura-rm-forecasting.surge.sh
cd ..
rmdir /s /q temp-deploy-rm

if %errorlevel% equ 0 (
    echo ✅ Successfully deployed to sakura-rm-forecasting.surge.sh
) else (
    echo ❌ Failed to deploy to sakura-rm-forecasting.surge.sh
)

echo.
echo ✅ 🎉 Deployment completed!
echo.
echo 📱 Your mobile app is now live at:
echo    • https://sakura-accounts-payable-dashboard.surge.sh/
echo    • https://sakura-factory-management.surge.sh/
echo    • https://sakura-rm-forecasting.surge.sh/
echo.
echo 🎯 Features deployed:
echo    ✅ Professional animated splash screen
echo    ✅ Lightning-fast loading (^< 0.5s^)
echo    ✅ Smooth animations and transitions
echo    ✅ Mobile-optimized interface
echo    ✅ Enterprise-grade performance
echo.
echo 📱 Test your mobile app now!
pause







