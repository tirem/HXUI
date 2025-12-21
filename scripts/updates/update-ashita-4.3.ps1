# Update Ashita v4beta 4.3 branch (2025_q3_update)
# Run from XIUI project root: .\scripts\updates\update-ashita-4.3.ps1

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Join-Path $scriptDir ".." ".." "ai-docs" "Ashita-v4beta-4.3"

Write-Host "Updating Ashita v4beta 4.3 (2025_q3_update branch)..." -ForegroundColor Cyan

if (Test-Path $repoDir) {
    Write-Host "Pulling latest changes..." -ForegroundColor Yellow
    Push-Location $repoDir
    try {
        git fetch origin
        git checkout 2025_q3_update
        git pull origin 2025_q3_update
        Write-Host "Successfully updated Ashita v4beta 4.3!" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "Cloning Ashita v4beta 4.3 branch..." -ForegroundColor Yellow
    git clone --branch 2025_q3_update --single-branch https://github.com/AshitaXI/Ashita-v4beta.git $repoDir
    Write-Host "Successfully cloned Ashita v4beta 4.3!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Repository location: $repoDir" -ForegroundColor Cyan
