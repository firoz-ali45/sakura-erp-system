@echo off
chcp 65001 >nul
title Sakura ERP - Starting...
color 0A

:: Add Node.js to PATH if not found (for double-click from Explorer)
if exist "C:\Program Files\nodejs\npm.cmd" set "PATH=C:\Program Files\nodejs;%PATH%"
if exist "C:\Program Files (x86)\nodejs\npm.cmd" set "PATH=C:\Program Files (x86)\nodejs;%PATH%"
if exist "%LOCALAPPDATA%\Programs\nodejs\npm.cmd" set "PATH=%LOCALAPPDATA%\Programs\nodejs;%PATH%"

where npm >nul 2>&1
if not %ERRORLEVEL%==0 (
    echo ERROR: 'npm' not found. Node.js install karo aur PATH mein add karo.
    echo Download: https://nodejs.org
    echo Install ke baad computer restart karo, phir dubara START_ERP.bat chalao.
    pause
    exit /b 1
)

echo ========================================
echo    Sakura ERP - Ek Click Mein Kholo
echo ========================================
echo.

cd /d "%~dp0"

if not exist "backend" (
    echo ERROR: backend folder nahi mila!
    echo Please ensure you're running this from sakura-erp-migration folder.
    pause
    exit /b 1
)

if not exist "frontend" (
    echo ERROR: frontend folder nahi mila!
    echo Please ensure you're running this from sakura-erp-migration folder.
    pause
    exit /b 1
)

echo [1/4] Checking setup...
if not exist "backend\node_modules" (
    echo.
    echo Pehli baar setup ho raha hai, thoda time lagega...
    echo.
    cd backend
    echo Installing backend packages...
    call npm install
    if not %ERRORLEVEL%==0 (
        echo.
        echo ERROR: npm install failed. Node.js installed hai?
        echo Please check if Node.js is installed: node --version
        pause
        exit /b 1
    )
    cd ..
    echo Backend packages installed successfully!
)

if not exist "frontend\node_modules" (
    cd frontend
    echo Installing frontend packages...
    call npm install
    if not %ERRORLEVEL%==0 (
        echo.
        echo ERROR: npm install failed.
        pause
        exit /b 1
    )
    cd ..
    echo Frontend packages installed successfully!
)

echo.
echo [2/4] Checking database...
cd backend
if not exist ".env" (
    echo.
    echo .env file nahi mili. Creating...
    (
        echo DATABASE_URL=postgresql://postgres:[Firoz112233@@]@db.bnkrdzsfjniiupnbuaye.supabase.co:5432/postgres
        echo JWT_SECRET="sakura-erp-secret-key-2024"
        echo JWT_EXPIRES_IN="7d"
        echo PORT=3000
        echo NODE_ENV=development
        echo CORS_ORIGIN="http://localhost:5173"
    ) > .env
    echo.
    echo IMPORTANT: .env file create ho gayi hai.
    echo Agar apka PostgreSQL password different hai, to .env file edit karo.
    echo.
    timeout /t 3 /nobreak >nul
)
cd ..

echo.
echo [3/4] Starting Backend Server...
start "Sakura ERP Backend" cmd /k "set PATH=%PATH% && cd /d %~dp0backend && echo Starting Backend... && npm run dev"
timeout /t 4 /nobreak >nul

echo.
echo [4/4] Starting Frontend...
start "Sakura ERP Frontend" cmd /k "set PATH=%PATH% && cd /d %~dp0frontend && echo Starting Frontend... && npm run dev"
timeout /t 6 /nobreak >nul

echo.
echo ========================================
echo    ERP Start Ho Gaya!
echo ========================================
echo.
echo Browser automatically khul jayega...
echo Agar nahi khula, to manually ye URL kholo:
echo.
echo    http://localhost:5173
echo.
echo Backend: http://localhost:3000
echo.
echo Dono windows (Backend aur Frontend) band mat karo!
echo Browser mein ERP khul jayega.
echo.
timeout /t 3 /nobreak >nul
start http://localhost:5173

echo.
echo Press any key to close this window...
echo (Servers abhi bhi chal rahe hain separate windows mein)
pause >nul
