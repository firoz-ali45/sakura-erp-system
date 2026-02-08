# Simple PowerShell Script - Supabase SQL Execution
# Ye script SQL file ko Supabase Dashboard mein automatically open karega

param(
    [Parameter(Mandatory=$true)]
    [string]$SqlFile
)

# Check if SQL file exists
if (-not (Test-Path $SqlFile)) {
    Write-Host "[ERROR] SQL file not found: $SqlFile" -ForegroundColor Red
    exit 1
}

# Read SQL content
Write-Host "[INFO] Reading SQL file: $SqlFile" -ForegroundColor Cyan
$sqlContent = Get-Content $SqlFile -Raw -Encoding UTF8

if ([string]::IsNullOrWhiteSpace($sqlContent)) {
    Write-Host "[ERROR] SQL file is empty" -ForegroundColor Red
    exit 1
}

# Copy SQL to clipboard
$sqlContent | Set-Clipboard

Write-Host ""
Write-Host "[SUCCESS] SQL content copied to clipboard!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Browser mein ye URL kholo:" -ForegroundColor White
Write-Host "      https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf/sql/new" -ForegroundColor Yellow
Write-Host ""
Write-Host "   2. SQL Editor mein paste karo (Ctrl+V)" -ForegroundColor White
Write-Host ""
Write-Host "   3. Run button click karo (ya Ctrl+Enter)" -ForegroundColor White
Write-Host ""

# Open browser to Supabase SQL Editor
Start-Process "https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf/sql/new"

Write-Host "[INFO] Browser opened! SQL already copied - just paste (Ctrl+V) and run!" -ForegroundColor Green
