# Update Ashita v4beta main branch
# Run from XIUI project root: .\scripts\updates\update-ashita-main.ps1

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Join-Path $scriptDir ".." ".." "ai-docs" "Ashita-v4beta"

Write-Host "Updating Ashita v4beta (main branch)..." -ForegroundColor Cyan

if (Test-Path $repoDir) {
    Write-Host "Pulling latest changes..." -ForegroundColor Yellow
    Push-Location $repoDir
    try {
        git fetch origin
        git checkout main
        git pull origin main
        Write-Host "Successfully updated Ashita v4beta main!" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "Cloning Ashita v4beta main branch..." -ForegroundColor Yellow
    git clone --branch main --single-branch https://github.com/AshitaXI/Ashita-v4beta.git $repoDir
    Write-Host "Successfully cloned Ashita v4beta main!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Repository location: $repoDir" -ForegroundColor Cyan
