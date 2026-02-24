# Run Unified Batch ID migration via Supabase SQL Editor
# Migration history mismatch ki wajah se supabase db push fail hota hai.
# Ye script SQL Editor link kholta hai - wahan paste karke Run karo.

$sqlPath = Join-Path $PSScriptRoot "migrations\20260224000000_unified_batch_id_grn_stock.sql"
$url = "https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf/sql/new"

Write-Host "Opening Supabase SQL Editor..." -ForegroundColor Cyan
Start-Process $url

Write-Host "`nMigration file: $sqlPath" -ForegroundColor Yellow
Write-Host "1. SQL Editor me file ka content paste karo" -ForegroundColor White
Write-Host "2. Run button click karo" -ForegroundColor White
Write-Host "`nOr copy to clipboard:" -ForegroundColor Green
Get-Content $sqlPath -Raw | Set-Clipboard
Write-Host "SQL copied to clipboard! Paste in SQL Editor (Ctrl+V)" -ForegroundColor Green
