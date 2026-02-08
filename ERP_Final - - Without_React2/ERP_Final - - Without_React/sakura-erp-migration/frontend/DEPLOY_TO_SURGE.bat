@echo off
REM Deploy Sakura ERP to All Three Surge URLs
REM This batch file deploys the complete system to all three Surge domains

echo ========================================
echo   Sakura ERP - Surge Deployment
echo ========================================
echo.

cd /d "%~dp0"

REM Check if dist folder exists
if not exist "dist" (
    echo ERROR: dist folder not found! Building first...
    call npm run build
    if not exist "dist" (
        echo ERROR: Build failed! Cannot deploy.
        pause
        exit /b 1
    )
)

REM Ensure _redirects file exists in dist
if not exist "dist\_redirects" (
    (
        echo /*    /index.html   200
    ) > "dist\_redirects"
    echo _redirects file created in dist folder
)

echo Deploying to all three Surge domains...
echo.

echo [1/3] Deploying to: sakura-factory-management.surge.sh
echo ----------------------------------------
surge dist sakura-factory-management.surge.sh --project dist
if %ERRORLEVEL% EQU 0 (
    echo [OK] Successfully deployed to sakura-factory-management.surge.sh
) else (
    echo [ERROR] Failed to deploy to sakura-factory-management.surge.sh
)
echo.

echo [2/3] Deploying to: sakura-accounts-payable-dashboard.surge.sh
echo ----------------------------------------
surge dist sakura-accounts-payable-dashboard.surge.sh --project dist
if %ERRORLEVEL% EQU 0 (
    echo [OK] Successfully deployed to sakura-accounts-payable-dashboard.surge.sh
) else (
    echo [ERROR] Failed to deploy to sakura-accounts-payable-dashboard.surge.sh
)
echo.

echo [3/3] Deploying to: sakura-rm-forecasting.surge.sh
echo ----------------------------------------
surge dist sakura-rm-forecasting.surge.sh --project dist
if %ERRORLEVEL% EQU 0 (
    echo [OK] Successfully deployed to sakura-rm-forecasting.surge.sh
) else (
    echo [ERROR] Failed to deploy to sakura-rm-forecasting.surge.sh
)
echo.

echo ========================================
echo   Deployment Complete!
echo ========================================
echo.
echo Your system is now live at:
echo   • https://sakura-factory-management.surge.sh
echo   • https://sakura-accounts-payable-dashboard.surge.sh
echo   • https://sakura-rm-forecasting.surge.sh
echo.
pause
