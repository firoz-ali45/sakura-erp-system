# Deploy Sakura ERP to All Three Surge URLs
# This script deploys the complete system to all three Surge domains

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Sakura ERP - Surge Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$distPath = "dist"
$domains = @(
    "sakura-factory-management.surge.sh",
    "sakura-accounts-payable-dashboard.surge.sh",
    "sakura-rm-forecasting.surge.sh"
)

# Safety Check: Database Migration
Write-Host "CRITICAL CHECK: Database Architecture Fixes" -ForegroundColor Yellow
Write-Host "Before deploying, you MUST execute the 'COMPLETE_ROOT_CAUSE_FIX_FINAL.sql' script in your Supabase SQL Editor."
Write-Host "This fixes the Purchase Order / Request ID mismatch issues."
$confirmation = Read-Host "Have you run the SQL migration script? (Y/N)"
if ($confirmation -ne "Y" -and $confirmation -ne "y") {
    Write-Host "Deployment cancelled. Please run the SQL script first." -ForegroundColor Red
    exit 1
}

# Check if dist folder exists
if (-not (Test-Path $distPath)) {
    Write-Host "ERROR: dist folder not found! Building first..." -ForegroundColor Red
    npm run build
    if (-not (Test-Path $distPath)) {
        Write-Host "ERROR: Build failed! Cannot deploy." -ForegroundColor Red
        exit 1
    }
}

# Ensure _redirects file exists in dist
$redirectsFile = Join-Path $distPath "_redirects"
if (-not (Test-Path $redirectsFile)) {
    $redirectsContent = @"
/*    /index.html   200
"@
    Set-Content -Path $redirectsFile -Value $redirectsContent
    Write-Host "_redirects file created in dist folder" -ForegroundColor Green
}

Write-Host "Deploying to all three Surge domains..." -ForegroundColor Yellow
Write-Host ""

$deployCount = 0

foreach ($domain in $domains) {
    $deployCount++
    Write-Host "[$deployCount/3] Deploying to: $domain" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    # Deploy using surge
    # Note: You may need to login first using: surge login
    surge $distPath $domain --project $distPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully deployed to $domain" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to deploy to $domain" -ForegroundColor Red
        Write-Host "  Error code: $LASTEXITCODE" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your system is now live at:" -ForegroundColor Green
foreach ($domain in $domains) {
    Write-Host "  • https://$domain" -ForegroundColor Yellow
}
Write-Host ""
