# Vercel CLI se deploy - sakura-erp-system-miuq project par deploy
# Pehli baar: npx vercel login

$frontendPath = Join-Path $PSScriptRoot "ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
$frontendPath = [System.IO.Path]::GetFullPath($frontendPath)
if (-not (Test-Path -LiteralPath $frontendPath)) {
  Write-Host "Frontend folder nahi mila: $frontendPath" -ForegroundColor Red
  exit 1
}
Push-Location -LiteralPath $frontendPath
try {
  Write-Host "Deploying to sakura-erp-system-miuq..." -ForegroundColor Cyan
  # Link to correct project (frontend was wrong)
  npx vercel link --yes --project sakura-erp-system-miuq 2>$null
  npx vercel --prod --yes
} finally {
  Pop-Location
}
