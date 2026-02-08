@echo off
echo ========================================
echo   Sakura ERP - Starting Dev Server
echo ========================================
echo.

cd /d "%~dp0"
echo Current Directory: %CD%
echo.

echo Stopping any existing Node processes...
taskkill /F /IM node.exe >nul 2>&1
timeout /t 2 >nul

echo.
echo Installing dependencies (if needed)...
call npm install

echo.
echo Starting Vite dev server...
echo.
echo Server will be available at: http://localhost:5173
echo.
echo Press Ctrl+C to stop the server
echo.

call npm run dev

pause

