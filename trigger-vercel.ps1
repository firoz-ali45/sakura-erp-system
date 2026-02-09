# Trigger Vercel deploy (latest commit) - push ke baad chalayo
# Deploy Hook URL: Vercel Dashboard -> Settings -> Git -> Deploy Hooks

$hookUrl = $env:VERCEL_DEPLOY_HOOK_URL
if (-not $hookUrl) {
  $hookUrl = "https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/CUAGmys2E7"
}

if ($hookUrl -match "PASTE_YOUR|REPLACE") {
  Write-Host "Pehle trigger-vercel.ps1 me apna Deploy Hook URL paste karo." -ForegroundColor Yellow
  exit 1
}

Write-Host "Triggering Vercel deploy (latest commit)..." -ForegroundColor Cyan
Write-Host "URL (last 20 chars): ...$($hookUrl.Substring([Math]::Max(0, $hookUrl.Length - 20)))" -ForegroundColor Gray
try {
  $r = Invoke-WebRequest -Uri $hookUrl -Method POST -UseBasicParsing
  Write-Host "Status: $($r.StatusCode)" -ForegroundColor $(if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 201) { "Green" } else { "Yellow" })
  if ($r.Content) {
    $json = $r.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($json.job) { Write-Host "Job ID: $($json.job.id)" -ForegroundColor Cyan }
    if ($json.error) { Write-Host "Vercel error: $($json.error)" -ForegroundColor Red }
    if (-not $json -and $r.Content.Length -lt 200) { Write-Host "Body: $($r.Content)" -ForegroundColor Gray }
  }
  if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 201) {
    Write-Host "Done. Vercel ko trigger bhej diya. 1-2 min me Deployments me nayi row aani chahiye." -ForegroundColor Green
  }
} catch {
  Write-Host "Error: $_" -ForegroundColor Red
  if ($_.Exception.Response) {
    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    Write-Host "Response: $($reader.ReadToEnd())" -ForegroundColor Red
  }
  exit 1
}
