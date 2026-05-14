# Vercel CLI se deploy - default: sakura-erp-system-new
# Pehli baar: npx vercel login   OR   session: $env:VERCEL_TOKEN = "<token>" (never commit token)
# Optional: $env:VERCEL_PROJECT = "other-project-name"
#
# Monorepo / Root Directory: Agar Vercel dashboard par is repo ke liye "Root Directory"
# already set hai (ERP_Final.../sakura-erp-migration/frontend), to CLI ko **repo root** se
# chalao — warna path double ho kar error aata hai (frontend\ERP_Final...\frontend).
# Agar dashboard par Root Directory **khali** hai, to yeh chalao:
#   $env:VERCEL_DEPLOY_CWD = "frontend"; .\deploy-vercel-cli.ps1

$vercelProject = if ($env:VERCEL_PROJECT) { $env:VERCEL_PROJECT } else { "sakura-erp-system-new" }
$deployFrom = if ($env:VERCEL_DEPLOY_CWD) { $env:VERCEL_DEPLOY_CWD.Trim().ToLowerInvariant() } else { "repo" }

$repoRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$frontendPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"))
if (-not (Test-Path -LiteralPath $frontendPath)) {
  Write-Host "Frontend folder nahi mila: $frontendPath" -ForegroundColor Red
  exit 1
}

$cwd = if ($deployFrom -eq "frontend") { $frontendPath } else { $repoRoot }
Push-Location -LiteralPath $cwd
try {
  Write-Host "Deploying $vercelProject (cwd: $cwd) ..." -ForegroundColor Cyan
  npx vercel link --yes --project $vercelProject 2>$null
  npx vercel --prod --yes
} finally {
  Pop-Location
}
