@echo off
REM Setup Script for Supabase Automation
REM Ye script Supabase CLI install karega (using Scoop or alternative methods)

echo ========================================
echo   Supabase Automation Setup
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

echo [INFO] Supabase CLI cannot be installed via npm globally.
echo [INFO] Using alternative installation methods...
echo.

REM Method 1: Try Scoop (Windows Package Manager - Recommended)
where scoop >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [STEP 1] Installing Supabase CLI using Scoop...
    echo.
    call scoop install supabase
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo [SUCCESS] Supabase CLI installed via Scoop!
        goto :verify
    )
)

REM Method 2: Try Chocolatey
where choco >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [STEP 1] Installing Supabase CLI using Chocolatey...
    echo.
    call choco install supabase -y
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo [SUCCESS] Supabase CLI installed via Chocolatey!
        goto :verify
    )
)

REM Method 3: Manual Installation Instructions
echo ========================================
echo   Manual Installation Required
echo ========================================
echo.
echo Supabase CLI ko manually install karna hoga.
echo.
echo Option 1: Scoop Install (Recommended)
echo   1. PowerShell (Admin) mein run karo:
echo      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
echo      irm get.scoop.sh ^| iex
echo   2. Phir: scoop install supabase
echo.
echo Option 2: Chocolatey Install
echo   1. Chocolatey install karo: https://chocolatey.org/install
echo   2. Phir: choco install supabase -y
echo.
echo Option 3: Direct Download
echo   1. Visit: https://github.com/supabase/cli/releases
echo   2. Latest release download karo
echo   3. Extract aur PATH mein add karo
echo.
echo Option 4: Use npx (No Installation Needed!)
echo   Abhi bhi use kar sakte ho without installing:
echo   npx supabase@latest login
echo   npx supabase@latest link --project-ref YOUR_PROJECT_REF
echo   npx supabase@latest db execute --file SQL_FILE.sql --linked
echo.
echo ========================================
echo   Quick Solution: Use npx (Recommended)
echo ========================================
echo.
echo Abhi bhi Supabase CLI use kar sakte ho WITHOUT installation!
echo.
echo Commands:
echo   npx supabase@latest login
echo   npx supabase@latest link --project-ref kexwnurwavszvmlpifsf
echo   npx supabase@latest db execute --file ADD_GRN_APPROVAL_COLUMNS.sql --linked
echo.
goto :end

:verify
echo.
echo [STEP 2] Verifying installation...
supabase --version

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   Setup Complete!
    echo ========================================
    echo.
    echo Next steps:
    echo   1. Run: supabase login
    echo   2. Run: supabase link --project-ref YOUR_PROJECT_REF
    echo   3. Then use: run-supabase-migration.bat ^<sql-file^>
    echo.
) else (
    echo.
    echo [WARNING] Supabase CLI not found in PATH
    echo Please use npx method (see instructions above)
)

:end
pause
