@echo off
REM Automated Supabase Migration Runner (Windows Batch Script)
REM Ye script automatically SQL files ko Supabase database mein run karega

echo ========================================
echo   Supabase Automated Migration Runner
echo ========================================
echo.

REM Check if Supabase CLI is installed
where supabase >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Supabase CLI not found!
    echo.
    echo Please install Supabase CLI first:
    echo   npm install -g supabase
    echo.
    pause
    exit /b 1
)

REM Check if project is linked
if not exist ".supabase\config.toml" (
    echo [WARNING] Supabase project not linked!
    echo.
    echo Please link your project first:
    echo   supabase login
    echo   supabase link --project-ref YOUR_PROJECT_REF
    echo.
    pause
    exit /b 1
)

REM Get SQL file from command line argument
set SQL_FILE=%1

if "%SQL_FILE%"=="" (
    echo [USAGE] run-supabase-migration.bat ^<sql-file^>
    echo [EXAMPLE] run-supabase-migration.bat ADD_GRN_APPROVAL_COLUMNS.sql
    echo.
    echo Available SQL files:
    dir /b *.sql
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
echo.

REM Execute SQL using Supabase CLI (for remote projects)
REM Note: For remote projects, we use db push or direct connection
echo [INFO] Executing SQL migration...
echo.

REM Method 1: Try Supabase CLI db push (if using migrations)
REM Method 2: Use direct PostgreSQL connection (more reliable for remote)
REM For now, we'll use psql if available, otherwise show instructions

where psql >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Use psql if available (requires DATABASE_URL in .env)
    echo [INFO] Using PostgreSQL client (psql)...
    REM This requires DATABASE_URL in .env file
    echo [NOTE] Make sure DATABASE_URL is set in .env file
    REM psql command would go here, but we'll use Supabase CLI instead
)

REM Use Supabase CLI db execute (works with linked projects)
supabase db execute --file "%SQL_FILE%" --linked

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ALTERNATIVE] If above failed, use Supabase Dashboard:
    echo   1. Open Supabase Dashboard
    echo   2. Go to SQL Editor
    echo   3. Copy content from: %SQL_FILE%
    echo   4. Paste and Run
    echo.
)

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   Migration Completed Successfully!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo   Migration Failed!
    echo ========================================
    echo.
    echo Please check the error message above.
)

echo.
pause

