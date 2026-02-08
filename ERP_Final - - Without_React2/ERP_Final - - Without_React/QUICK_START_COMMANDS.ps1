# Quick Start Script for Vue.js Template
# PowerShell me ye file run karo: .\QUICK_START_COMMANDS.ps1

Write-Host "🚀 Starting Vue.js Template..." -ForegroundColor Green

# Navigate to Vue.js template
$vuePath = "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"
Set-Location $vuePath

Write-Host "✅ Navigated to Vue.js template folder" -ForegroundColor Green

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
