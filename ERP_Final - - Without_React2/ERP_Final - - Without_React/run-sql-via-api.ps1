# PowerShell Script to Run SQL via Supabase REST API
# Ye script Supabase REST API use karke SQL files run karega (No psql needed!)

param(
    [Parameter(Mandatory=$true)]
    [string]$SqlFile
)

# Supabase Configuration (apne project se replace karein)
$SUPABASE_URL = "https://kexwnurwavszvmlpifsf.supabase.co"
$SUPABASE_SERVICE_KEY = ""  # Service role key (Settings → API → service_role key)

# Check if SQL file exists
if (-not (Test-Path $SqlFile)) {
    Write-Host "❌ Error: SQL file not found: $SqlFile" -ForegroundColor Red
    exit 1
}

# Read SQL content
Write-Host "📂 Reading SQL file: $SqlFile" -ForegroundColor Cyan
$sqlContent = Get-Content $SqlFile -Raw

if ([string]::IsNullOrWhiteSpace($sqlContent)) {
    Write-Host "❌ Error: SQL file is empty" -ForegroundColor Red
    exit 1
}

# Check if service key is set
if ([string]::IsNullOrWhiteSpace($SUPABASE_SERVICE_KEY)) {
    Write-Host "⚠️  Warning: Service role key not set in script" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Please use Method 2 (Supabase Dashboard) instead:" -ForegroundColor Cyan
    Write-Host "   1. Open Supabase Dashboard" -ForegroundColor White
    Write-Host "   2. Go to SQL Editor" -ForegroundColor White
    Write-Host "   3. Copy content from: $SqlFile" -ForegroundColor White
    Write-Host "   4. Paste and Run" -ForegroundColor White
    Write-Host ""
    Write-Host "Or set SUPABASE_SERVICE_KEY in this script (line 9)" -ForegroundColor Yellow
    Write-Host "   Get it from: Supabase Dashboard → Settings → API → service_role key" -ForegroundColor Yellow
    exit 1
}

Write-Host "🚀 Executing SQL via Supabase REST API..." -ForegroundColor Green
Write-Host ""

# Execute SQL via Supabase REST API
try {
    $headers = @{
        "apikey" = $SUPABASE_SERVICE_KEY
        "Authorization" = "Bearer $SUPABASE_SERVICE_KEY"
        "Content-Type" = "application/json"
    }

    $body = @{
        query = $sqlContent
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/exec_sql" -Method Post -Headers $headers -Body $body -ErrorAction Stop

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   Migration Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "   Migration Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "📝 Alternative: Use Supabase Dashboard SQL Editor" -ForegroundColor Yellow
    Write-Host "   1. Open: https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf/sql" -ForegroundColor White
    Write-Host "   2. Copy content from: $SqlFile" -ForegroundColor White
    Write-Host "   3. Paste and Run" -ForegroundColor White
    exit 1
}
