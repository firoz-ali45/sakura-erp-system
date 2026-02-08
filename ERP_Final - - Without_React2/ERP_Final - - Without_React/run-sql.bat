@echo off
setlocal enabledelayedexpansion
REM Simple Batch Wrapper for PowerShell Script
REM Ye script kisi bhi directory se run kar sakte ho

echo ========================================
echo   Supabase SQL Runner
echo ========================================
echo.

REM Get SQL file from command line argument
set SQL_FILE=%1

if "%SQL_FILE%"=="" (
    echo [USAGE] run-sql.bat ^<sql-file^>
    echo [EXAMPLE] run-sql.bat ADD_GRN_APPROVAL_COLUMNS.sql
    echo.
    echo Available SQL files:
    dir /b *.sql 2>nul
    echo.
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Check if SQL file exists in current directory or script directory
if not exist "%SQL_FILE%" (
    set "FULL_PATH=%SCRIPT_DIR%%SQL_FILE%"
    if exist "!FULL_PATH!" (
        set "SQL_FILE=!FULL_PATH!"
    ) else (
        echo [ERROR] SQL file not found: %SQL_FILE%
        echo.
        echo Please provide full path or ensure file is in current directory.
        pause
        exit /b 1
    )
)

REM Check if PowerShell script exists
if not exist "%SCRIPT_DIR%run-sql-simple.ps1" (
    echo [ERROR] PowerShell script not found: run-sql-simple.ps1
    echo.
    echo Please ensure run-sql-simple.ps1 is in the same folder as this batch file.
    pause
    exit /b 1
)

echo [INFO] Running SQL file: %SQL_FILE%
echo [INFO] Using PowerShell script...
echo.

REM Run PowerShell script
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run-sql-simple.ps1" "%SQL_FILE%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Script execution failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Done!
echo ========================================
echo.
pause
