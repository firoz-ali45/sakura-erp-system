# PowerShell Script for Direct SQL Execution
# Ye script directly Supabase database se connect karke SQL run karega

param(
    [Parameter(Mandatory=$true)]
    [string]$SqlFile
)

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Get database URL from environment
$databaseUrl = $env:DATABASE_URL

if (-not $databaseUrl) {
    Write-Host "❌ Error: DATABASE_URL not found in .env file" -ForegroundColor Red
    Write-Host "📝 Please add DATABASE_URL to .env file:" -ForegroundColor Yellow
    Write-Host "   DATABASE_URL=postgresql://postgres:[PASSWORD]@db.xxxxx.supabase.co:5432/postgres" -ForegroundColor Yellow
    exit 1
}

# Check if psql is available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if (-not $psqlPath) {
    Write-Host "❌ Error: PostgreSQL client (psql) not found!" -ForegroundColor Red
    Write-Host "📝 Please install PostgreSQL client:" -ForegroundColor Yellow
    Write-Host "   Download from: https://www.postgresql.org/download/windows/" -ForegroundColor Yellow
    Write-Host "   Or use: choco install postgresql" -ForegroundColor Yellow
    exit 1
}

# Check if SQL file exists
if (-not (Test-Path $SqlFile)) {
    Write-Host "❌ Error: SQL file not found: $SqlFile" -ForegroundColor Red
    exit 1
}

Write-Host "📂 Reading SQL file: $SqlFile" -ForegroundColor Cyan
$sqlContent = Get-Content $SqlFile -Raw

if ([string]::IsNullOrWhiteSpace($sqlContent)) {
    Write-Host "❌ Error: SQL file is empty" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Executing SQL migration..." -ForegroundColor Green
Write-Host ""

# Execute SQL using psql
$sqlContent | & psql $databaseUrl

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "   Migration Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "   Migration Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error message above." -ForegroundColor Yellow
    exit 1
}


