# Commit + Push + Vercel Deploy — Ek hi script me sab
# Usage: .\commit-and-deploy.ps1
# Custom message: .\commit-and-deploy.ps1 "Transfer order UI fix"

Set-Location $PSScriptRoot

$msg = "Sync: " + (Get-Date -Format "yyyy-MM-dd HH:mm") + " - worktree updates"
if ($args.Count -gt 0) { $msg = $args[0] }

Write-Host "=== 1. Git Add + Commit + Push ===" -ForegroundColor Cyan
git add -A
$status = git status --short
if (-not $status) {
  Write-Host "No changes to commit." -ForegroundColor Yellow
  Write-Host "Vercel trigger kar rahe hain (last commit)..." -ForegroundColor Cyan
} else {
  git commit -m $msg
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git push origin main
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host "Git push done." -ForegroundColor Green
}

Write-Host "`n=== 2. Vercel Deploy Trigger ===" -ForegroundColor Cyan
$hookUrl = $env:VERCEL_DEPLOY_HOOK_URL
if (-not $hookUrl) {
  $hookUrl = "https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/CUAGmys2E7"
}
try {
  $r = Invoke-WebRequest -Uri $hookUrl -Method POST -UseBasicParsing
  Write-Host "Vercel: $($r.StatusCode)" -ForegroundColor $(if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 201) { "Green" } else { "Yellow" })
  if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 201) {
    Write-Host "Done. Git + Vercel update ho gaya." -ForegroundColor Green
  }
} catch {
  Write-Host "Vercel trigger error: $_" -ForegroundColor Red
  exit 1
}
