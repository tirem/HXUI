# Update both Ashita v4beta branches (main and 4.3)
# Run from XIUI project root: .\scripts\updates\update-ashita-all.ps1

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Updating All Ashita v4beta Branches" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# Update main
& "$scriptDir\update-ashita-main.ps1"
Write-Host ""

# Update 4.3
& "$scriptDir\update-ashita-4.3.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  All branches updated!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
