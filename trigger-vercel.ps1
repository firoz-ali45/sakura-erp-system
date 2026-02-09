# Trigger Vercel deploy (latest commit) — use when push se auto-deploy nahi ho raha
# Pehle Vercel me Deploy Hook banao, URL yahan paste karo (see VERCELL_DEPLOY_HOOK_SETUP.md)

$hookUrl = $env:VERCEL_DEPLOY_HOOK_URL
if (-not $hookUrl) {
  # Yahan apna Deploy Hook URL paste karo (Vercel Dashboard se copy karke)
  $hookUrl = "https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/aR90lrhDsN"
}
if ($hookUrl -eq "PASTE_YOUR_VERCEL_DEPLOY_HOOK_URL_HERE") {
  Write-Host "Vercel Deploy Hook URL set nahi hai." -ForegroundColor Yellow
  Write-Host "VERCELL_DEPLOY_HOOK_SETUP.md dekho — Vercel me Hook banao, URL yahan ya env me set karo." -ForegroundColor Cyan
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
