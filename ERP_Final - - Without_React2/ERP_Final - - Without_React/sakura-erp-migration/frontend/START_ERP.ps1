# Sakura ERP - Start Dev Server Script
# Double-click this file to start the ERP

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Sakura ERP - Starting Dev Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "Current Directory: $PWD" -ForegroundColor Green
Write-Host ""

# Stop any existing Node processes
Write-Host "Stopping any existing Node processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Installing dependencies (if needed)..." -ForegroundColor Yellow
npm install

Write-Host ""
Write-Host "Starting Vite dev server..." -ForegroundColor Green
Write-Host ""
Write-Host "Server will be available at: http://localhost:5173" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

npm run dev

