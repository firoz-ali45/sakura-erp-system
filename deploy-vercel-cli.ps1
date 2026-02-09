# Vercel CLI se deploy - Deploy Hook agar kaam na kare to use karo
# Pehli baar: npx vercel login, phir npx vercel link (sakura-erp-system-miuq choose karo)

$frontendPath = Join-Path $PSScriptRoot "ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
$frontendPath = [System.IO.Path]::GetFullPath($frontendPath)
if (-not (Test-Path -LiteralPath $frontendPath)) {
  Write-Host "Frontend folder nahi mila: $frontendPath" -ForegroundColor Red
  exit 1
}
Push-Location -LiteralPath $frontendPath
try {
  Write-Host "Deploying from: $frontendPath" -ForegroundColor Cyan
  Write-Host "Vercel login agar nahi kiya to pehle vercel login karo." -ForegroundColor Yellow
  npx vercel --prod --yes
} finally {
  Pop-Location
}
