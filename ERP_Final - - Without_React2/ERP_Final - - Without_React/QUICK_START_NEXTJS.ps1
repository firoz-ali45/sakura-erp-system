# Quick Start Script for Next.js Template
# PowerShell me ye file run karo: .\QUICK_START_NEXTJS.ps1

Write-Host "🚀 Starting Next.js Template..." -ForegroundColor Green

# Navigate to Next.js template
$nextjsPath = "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\nextjs-starter-template"
Set-Location $nextjsPath

Write-Host "✅ Navigated to Next.js template folder" -ForegroundColor Green

# Check if node_modules exists
if (-not (Test-Path "node_modules")) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    npm install
} else {
    Write-Host "✅ Dependencies already installed" -ForegroundColor Green
}

# Start development server
Write-Host "🔥 Starting development server..." -ForegroundColor Cyan
npm run dev
