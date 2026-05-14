# Vercel CLI se deploy - default: sakura-erp-system-new
# Pehli baar: npx vercel login   OR   session: $env:VERCEL_TOKEN = "<token>" (never commit token)
# Optional override: $env:VERCEL_PROJECT = "other-project-name"

$vercelProject = if ($env:VERCEL_PROJECT) { $env:VERCEL_PROJECT } else { "sakura-erp-system-new" }

$frontendPath = Join-Path $PSScriptRoot "ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
$frontendPath = [System.IO.Path]::GetFullPath($frontendPath)
if (-not (Test-Path -LiteralPath $frontendPath)) {
  Write-Host "Frontend folder nahi mila: $frontendPath" -ForegroundColor Red
  exit 1
}
Push-Location -LiteralPath $frontendPath
try {
  Write-Host "Deploying to $vercelProject ..." -ForegroundColor Cyan
  npx vercel link --yes --project $vercelProject 2>$null
  npx vercel --prod --yes
} finally {
  Pop-Location
}
