################################################################################
# Complete Cleanup Script for Development Environment - v0.5.6 (PowerShell)
# WARNING: This will delete ALL development environment data
################################################################################

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Load environment variables
$EnvFile = Join-Path $ScriptDir ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

Write-Header "COMPLETE CLEANUP - Development Environment"

Write-Host ""
Write-Host "This script will DELETE the following:" -ForegroundColor Yellow
Write-Host "  - All Docker containers (dev-container, dev-mongodb, dev-mongo-express)" -ForegroundColor White
Write-Host "  - All Docker images related to this project" -ForegroundColor White
Write-Host "  - All Docker networks (dev-network)" -ForegroundColor White
Write-Host "  - Project directory: $env:PROJECT_PATH" -ForegroundColor White
Write-Host "  - MongoDB data: $env:VOLUME_MONGODB_DATA" -ForegroundColor White
Write-Host "  - MongoDB init: $env:VOLUME_MONGODB_INIT" -ForegroundColor White
Write-Host "  - Cargo cache: $env:VOLUME_CARGO_CACHE" -ForegroundColor White
Write-Host "  - Target cache: $env:VOLUME_TARGET_CACHE" -ForegroundColor White
Write-Host "  - Local MongoDB init script: $ScriptDir\01-init-db.js" -ForegroundColor White
Write-Host ""
Write-Host "THIS CANNOT BE UNDONE!" -ForegroundColor Red
Write-Host ""

$confirmation = Read-Host "Type 'YES' to confirm complete cleanup"

if ($confirmation -ne "YES") {
    Write-Host "Cleanup cancelled." -ForegroundColor Green
    exit 0
}

Write-Host ""

################################################################################
# Stop and Remove Containers
################################################################################

Write-Header "Stopping and Removing Containers"

try {
    Set-Location $ScriptDir
    docker compose -f docker-compose-dev.yml down -v 2>$null
    Write-Success "Containers and networks removed"
} catch {
    Write-Warning-Custom "No running containers found or error stopping them"
}

################################################################################
# Remove Images
################################################################################

Write-Header "Removing Docker Images"

$imagesToRemove = @(
    "dev-container",
    "dev-container:latest"
)

foreach ($image in $imagesToRemove) {
    try {
        docker rmi $image -f 2>$null
        Write-Success "Removed image: $image"
    } catch {
        Write-Warning-Custom "Image not found: $image"
    }
}

################################################################################
# Remove Bind-Mounted Directories
################################################################################

Write-Header "Removing Bind-Mounted Directories"

$directoriesToRemove = @(
    @{Path="$env:PROJECT_PATH"; Name="Project directory"},
    @{Path="$env:VOLUME_MONGODB_DATA"; Name="MongoDB data"},
    @{Path="$env:VOLUME_MONGODB_INIT"; Name="MongoDB init"},
    @{Path="$env:VOLUME_CARGO_CACHE"; Name="Cargo cache"},
    @{Path="$env:VOLUME_TARGET_CACHE"; Name="Target cache"}
)

foreach ($dir in $directoriesToRemove) {
    if (Test-Path $dir.Path) {
        try {
            Remove-Item -Path $dir.Path -Recurse -Force -ErrorAction Stop
            Write-Success "Removed: $($dir.Name) ($($dir.Path))"
        } catch {
            Write-Warning-Custom "Failed to remove: $($dir.Name) ($($dir.Path))"
            Write-Host "  Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Not found: $($dir.Name) ($($dir.Path))" -ForegroundColor Gray
    }
}

# Remove local MongoDB init script file
$mongoInitFile = "$ScriptDir\01-init-db.js"
if (Test-Path $mongoInitFile) {
    try {
        Remove-Item -Path $mongoInitFile -Force -ErrorAction Stop
        Write-Success "Removed: Local MongoDB init script ($mongoInitFile)"
    } catch {
        Write-Warning-Custom "Failed to remove: Local MongoDB init script ($mongoInitFile)"
        Write-Host "  Error: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[-] Not found: Local MongoDB init script ($mongoInitFile)" -ForegroundColor Gray
}

################################################################################
# Docker System Cleanup
################################################################################

Write-Header "Docker System Cleanup"

Write-Host "Pruning unused Docker data..." -ForegroundColor Yellow
docker system prune -f --volumes 2>$null
Write-Success "Docker system pruned"

Write-Host "Pruning Docker build cache..." -ForegroundColor Yellow
docker builder prune -f 2>$null
Write-Success "Docker build cache pruned"

################################################################################
# Verification
################################################################################

Write-Header "Verification"

Write-Host "Remaining containers:" -ForegroundColor Cyan
docker ps -a --filter "name=dev-" --format "table {{.Names}}\t{{.Status}}"

Write-Host ""
Write-Host "Remaining images:" -ForegroundColor Cyan
docker images --filter "reference=*dev*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

Write-Host ""
Write-Host "Remaining volumes:" -ForegroundColor Cyan
docker volume ls --filter "name=dev"

Write-Host ""
Write-Host "Project directory contents:" -ForegroundColor Cyan
if (Test-Path $env:PROJECT_PATH) {
    Get-ChildItem -Path $env:PROJECT_PATH -Force | Format-Table Name, Length, LastWriteTime
} else {
    Write-Host "  (Directory does not exist)" -ForegroundColor Gray
}

################################################################################
# Complete
################################################################################

Write-Host ""
Write-Header "Cleanup Complete"
Write-Host ""
Write-Success "All development environment data has been removed."
Write-Host ""
Write-Host "To redeploy the environment, run:" -ForegroundColor Cyan
Write-Host "  .\deploy-dev.ps1" -ForegroundColor White
Write-Host ""
