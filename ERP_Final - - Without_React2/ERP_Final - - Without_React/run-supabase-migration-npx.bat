@echo off
REM Automated Supabase Migration Runner (Using npx - No Installation Needed!)
REM Ye script automatically SQL files ko Supabase database mein run karega

echo ========================================
echo   Supabase Migration Runner (npx)
echo ========================================
echo.

REM Check Node.js
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js not found!
    echo Please install Node.js first: https://nodejs.org
    pause
    exit /b 1
)

REM Get SQL file from command line argument
set SQL_FILE=%1

if "%SQL_FILE%"=="" (
    echo [USAGE] run-supabase-migration-npx.bat ^<sql-file^>
    echo [EXAMPLE] run-supabase-migration-npx.bat ADD_GRN_APPROVAL_COLUMNS.sql
    echo.
    echo Available SQL files:
    dir /b *.sql 2>nul
    echo.
    pause
    exit /b 1
)

REM Check if file exists
if not exist "%SQL_FILE%" (
    echo [ERROR] SQL file not found: %SQL_FILE%
    pause
    exit /b 1
)

echo [INFO] Running SQL migration: %SQL_FILE%
echo [INFO] Using npx (no installation needed!)
echo.

REM Check if project is linked
if not exist ".supabase\config.toml" (
    echo [WARNING] Supabase project not linked!
    echo.
    echo Please link your project first:
    echo   npx supabase@latest login
    echo   npx supabase@latest link --project-ref YOUR_PROJECT_REF
    echo.
    echo Or use manual method in Supabase Dashboard
    echo.
    pause
    exit /b 1
)

REM Execute SQL using PowerShell script (better method)
echo [INFO] Executing SQL migration via PowerShell...
echo.

REM Check if PowerShell script exists
if exist "run-sql-simple.ps1" (
    powershell -ExecutionPolicy Bypass -File "run-sql-simple.ps1" "%SQL_FILE%"
) else (
    echo.
    echo [WARNING] PowerShell script not found. Using manual method...
    echo.
    echo ========================================
    echo   Manual SQL Execution Required
    echo ========================================
    echo.
    echo [STEP 1] Open Supabase Dashboard:
    echo   https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf/sql/new
    echo.
    echo [STEP 2] Open SQL file: %SQL_FILE%
    echo.
    echo [STEP 3] Copy all content (Ctrl+A, Ctrl+C)
    echo.
    echo [STEP 4] Paste in Supabase SQL Editor (Ctrl+V)
    echo.
    echo [STEP 5] Click Run button (or press Ctrl+Enter)
    echo.
    echo [INFO] Opening SQL file in notepad for easy copy...
    notepad "%SQL_FILE%"
)

echo.
pause


