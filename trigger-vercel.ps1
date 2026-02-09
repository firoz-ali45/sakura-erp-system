# Trigger Vercel deploy (latest commit) - push ke baad chalayo
# Deploy Hook URL: Vercel Dashboard -> Settings -> Git -> Deploy Hooks

$hookUrl = $env:VERCEL_DEPLOY_HOOK_URL
if (-not $hookUrl) {
  $hookUrl = "https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/aR90lrhDsN"
}

if ($hookUrl -match "PASTE_YOUR|REPLACE") {
  Write-Host "Pehle trigger-vercel.ps1 me apna Deploy Hook URL paste karo." -ForegroundColor Yellow
  exit 1
}

Write-Host "Triggering Vercel deploy (latest commit)..." -ForegroundColor Cyan
try {
  $r = Invoke-WebRequest -Uri $hookUrl -Method POST -UseBasicParsing
  if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 201) {
    Write-Host "Done. Vercel deploy trigger ho gaya. 1-2 min me site update ho jayegi." -ForegroundColor Green
  } else {
    Write-Host "Response: $($r.StatusCode)" -ForegroundColor Yellow
  }
} catch {
  Write-Host "Error: $_" -ForegroundColor Red
  exit 1
}
