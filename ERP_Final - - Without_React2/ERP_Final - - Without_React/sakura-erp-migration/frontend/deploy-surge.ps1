# PowerShell Deployment Script for Surge.sh
# Deploys Vue 3 ERP app to 3 Surge domains

Write-Host "🚀 Sakura ERP - Surge.sh Production Deployment" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if Surge CLI is installed
$surgeInstalled = Get-Command surge -ErrorAction SilentlyContinue
if (-not $surgeInstalled) {
    Write-Host "❌ Surge CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g surge
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install Surge CLI" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Surge CLI installed successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Surge CLI is already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "📦 Building production bundle..." -ForegroundColor Cyan

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
}

# Build the app
Write-Host "Building Vue app..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build completed successfully" -ForegroundColor Green

# Ensure 200.html exists for SPA routing
if (-not (Test-Path "dist\200.html")) {
    Write-Host "Creating 200.html for Surge SPA routing..." -ForegroundColor Yellow
    Copy-Item "dist\index.html" "dist\200.html"
}

Write-Host ""
Write-Host "🌐 Deploying to all 3 Surge domains..." -ForegroundColor Cyan
Write-Host ""

# Domains to deploy to
$domains = @(
    "sakura-accounts-payable-dashboard.surge.sh",
    "sakura-factory-management.surge.sh",
    "sakura-rm-forecasting.surge.sh"
)

$successCount = 0

foreach ($domain in $domains) {
    Write-Host "📤 Deploying to: https://$domain/" -ForegroundColor Yellow
    
    # Deploy to Surge
    Push-Location "dist"
    surge . $domain --domain $domain
    $deployResult = $LASTEXITCODE
    Pop-Location
    
    if ($deployResult -eq 0) {
        Write-Host "✅ Successfully deployed to $domain" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "❌ Failed to deploy to $domain" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "=============================================" -ForegroundColor Cyan
if ($successCount -eq 3) {
    Write-Host "🎉 All deployments successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📱 Your ERP is now live at:" -ForegroundColor Cyan
    Write-Host "   • https://sakura-accounts-payable-dashboard.surge.sh/" -ForegroundColor White
    Write-Host "   • https://sakura-factory-management.surge.sh/" -ForegroundColor White
    Write-Host "   • https://sakura-rm-forecasting.surge.sh/" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ Production deployment complete!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some deployments failed. Success: $successCount/3" -ForegroundColor Yellow
    exit 1
}
