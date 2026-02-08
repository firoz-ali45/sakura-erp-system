@echo off
chcp 65001 >nul
echo ========================================
echo    Database Migrations Run Karo
echo ========================================
echo.

cd /d "%~dp0backend"

echo [1/3] Checking dependencies...
if not exist "node_modules" (
    echo Installing npm packages...
    call npm install
    if errorlevel 1 (
        echo ERROR: npm install failed!
        pause
        exit /b 1
    )
)

echo.
echo [2/3] Generating Prisma Client...
call npm run prisma:generate
if errorlevel 1 (
    echo ERROR: Prisma generate failed!
    pause
    exit /b 1
)

echo.
echo [3/3] Running Database Migrations...
echo.
echo IMPORTANT: Pehle database 'sakura_erp' create karna hai pgAdmin se!
echo.
pause

call npm run prisma:migrate
if errorlevel 1 (
    echo.
    echo ERROR: Migration failed!
    echo.
    echo Check karo:
    echo 1. Database 'sakura_erp' create ho gaya hai?
    echo 2. .env file mein correct DATABASE_URL hai?
    echo 3. PostgreSQL service running hai?
    pause
    exit /b 1
)

echo.
echo ========================================
echo    ✅ Migrations Successful!
echo ========================================
echo.
echo Database tables create ho gaye hain!
echo.
pause

