# Vercel CLI se deploy - Deploy Hook agar kaam na kare to use karo
# Pehli baar: npm i -g vercel (ya npx vercel) aur login

$frontendPath = Join-Path $PSScriptRoot "ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
if (-not (Test-Path $frontendPath)) {
  Write-Host "Frontend folder nahi mila: $frontendPath" -ForegroundColor Red
  exit 1
}
Set-Location $frontendPath
Write-Host "Deploying from: $frontendPath" -ForegroundColor Cyan
Write-Host "Vercel login agar nahi kiya to pehle vercel login karo." -ForegroundColor Yellow
npx vercel --prod --yes
