# Sync all project changes to Git repo (add + commit + push)
# Run this after any edits in this folder - sab direct repo me chala jayega
# Usage: Right-click script -> Run with PowerShell, OR in terminal: .\sync-to-git.ps1

Set-Location $PSScriptRoot

$msg = "Sync: " + (Get-Date -Format "yyyy-MM-dd HH:mm") + " - project updates"
if ($args.Count -gt 0) { $msg = $args[0] }

Write-Host "Adding all changes..." -ForegroundColor Cyan
git add -A
$status = git status --short
if (-not $status) {
  Write-Host "No changes to commit. Repo is already up to date." -ForegroundColor Yellow
  exit 0
}
Write-Host "Committing..." -ForegroundColor Cyan
# Vercel requires commit author to have team access - use authorized email
$author = if ($env:GIT_AUTHOR_EMAIL) { $env:GIT_AUTHOR_EMAIL } else { "Shahfiroz3344@gmail.com" }
$authorName = if ($env:GIT_AUTHOR_NAME) { $env:GIT_AUTHOR_NAME } else { "firoz-ali45" }
git -c user.email=$author -c user.name=$authorName commit -m $msg
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Pushing to origin main..." -ForegroundColor Cyan
# Worktree-safe: push current branch to main (no need to checkout main)
git push origin HEAD:main
if ($LASTEXITCODE -eq 0) {
  Write-Host "Done. Repo updated." -ForegroundColor Green
} else {
  Write-Host "Push failed. Check remote and try again." -ForegroundColor Red
}
