@echo off
chcp 65001 >nul
echo ========================================
echo    Sakura ERP - Ek Click Mein Kholo
echo ========================================
echo.

cd /d "%~dp0"

echo [1/4] Checking setup...
if not exist "backend\node_modules" (
    echo.
    echo Pehli baar setup ho raha hai, thoda time lagega...
    echo.
    cd backend
    echo Installing backend packages...
    call npm install
    if errorlevel 1 (
        echo ERROR: npm install failed. Node.js installed hai?
        pause
        exit /b 1
    )
    cd ..
)

if not exist "frontend\node_modules" (
    cd frontend
    echo Installing frontend packages...
    call npm install
    if errorlevel 1 (
        echo ERROR: npm install failed.
        pause
        exit /b 1
    )
    cd ..
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
    pause
)

echo.
echo [3/4] Starting Backend Server...
start "Sakura ERP Backend" cmd /k "cd /d %~dp0backend && npm run dev"
timeout /t 3 /nobreak >nul

echo.
echo [4/4] Starting Frontend...
start "Sakura ERP Frontend" cmd /k "cd /d %~dp0frontend && npm run dev"
timeout /t 5 /nobreak >nul

echo.
echo ========================================
echo    ✅ ERP Start Ho Gaya!
echo ========================================
echo.
echo Browser automatically khul jayega...
echo Agar nahi khula, to manually ye URL kholo:
echo.
echo    http://localhost:5173
echo.
echo Backend: http://localhost:3000
echo.
timeout /t 2 /nobreak >nul
start http://localhost:5173

echo.
echo Dono windows (Backend aur Frontend) band mat karo!
echo Browser mein ERP khul jayega.
echo.
pause

