# Vercel Deploy Hook - trigger deployment for main branch
# Usage: Run this script after pasting your hook URL below, or pass URL as argument:
#   .\trigger-vercel-deploy.ps1
#   .\trigger-vercel-deploy.ps1 -HookUrl "https://api.vercel.com/v1/integrations/deploy/..."

param(
    [string]$HookUrl = "PASTE_YOUR_DEPLOY_HOOK_URL_HERE"
)

if ($HookUrl -eq "PASTE_YOUR_DEPLOY_HOOK_URL_HERE") {
    Write-Host "Error: Paste your Deploy Hook URL in this script (replace PASTE_YOUR_DEPLOY_HOOK_URL_HERE)" -ForegroundColor Yellow
    Write-Host "Or run: .\trigger-vercel-deploy.ps1 -HookUrl 'https://api.vercel.com/v1/integrations/deploy/...'" -ForegroundColor Gray
    exit 1
}

Write-Host "Triggering Vercel deployment..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $HookUrl -Method POST -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json
    Write-Host "OK - Job ID: $($json.job.id), State: $($json.job.state)" -ForegroundColor Green
    Write-Host "Check Vercel Dashboard -> Deployments for the new build." -ForegroundColor Gray
} catch {
    Write-Host "Request failed: $_" -ForegroundColor Red
    exit 1
}
