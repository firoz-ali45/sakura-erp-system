# PowerShell Script for Starting Sakura ERP
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Sakura ERP - Ek Click Mein Kholo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Change to script directory
Set-Location $PSScriptRoot

Write-Host "[1/4] Checking setup..." -ForegroundColor Yellow

# Check backend node_modules
if (-not (Test-Path "backend\node_modules")) {
    Write-Host ""
    Write-Host "Pehli baar setup ho raha hai, thoda time lagega..." -ForegroundColor Yellow
    Write-Host ""
    Set-Location backend
    Write-Host "Installing backend packages..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: npm install failed. Node.js installed hai?" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    Set-Location ..
}

# Check frontend node_modules
if (-not (Test-Path "frontend\node_modules")) {
    Set-Location frontend
    Write-Host "Installing frontend packages..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: npm install failed." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    Set-Location ..
}

Write-Host ""
Write-Host "[2/4] Checking database..." -ForegroundColor Yellow
Set-Location backend

if (-not (Test-Path ".env")) {
    Write-Host ""
    Write-Host ".env file nahi mili. Creating..." -ForegroundColor Yellow
    @"
DATABASE_URL=postgresql://postgres:[Firoz112233@@]@db.bnkrdzsfjniiupnbuaye.supabase.co:5432/postgres
JWT_SECRET="sakura-erp-secret-key-2024"
JWT_EXPIRES_IN="7d"
PORT=3000
NODE_ENV=development
CORS_ORIGIN="http://localhost:5173"
"@ | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host ""
    Write-Host "IMPORTANT: .env file create ho gayi hai." -ForegroundColor Green
    Write-Host "Agar apka PostgreSQL password different hai, to .env file edit karo." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue"
}

Set-Location ..

Write-Host ""
Write-Host "[3/4] Starting Backend Server..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\backend'; npm run dev" -WindowStyle Normal

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "[4/4] Starting Frontend..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\frontend'; npm run dev" -WindowStyle Normal

Start-Sleep -Seconds 5

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   ✅ ERP Start Ho Gaya!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Browser automatically khul jayega..." -ForegroundColor Yellow
Write-Host "Agar nahi khula, to manually ye URL kholo:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   http://localhost:5173" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend: http://localhost:3000" -ForegroundColor Cyan
Write-Host ""

Start-Sleep -Seconds 2
Start-Process "http://localhost:5173"

Write-Host ""
Write-Host "Dono windows (Backend aur Frontend) band mat karo!" -ForegroundColor Yellow
Write-Host "Browser mein ERP khul jayega." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to exit"


