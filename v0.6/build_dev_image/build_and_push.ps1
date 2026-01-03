################################################################################
# Build and Push Rust Dev Container Image (Windows)
# Usage: .\build_and_push.ps1 [VERSION]
################################################################################

param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

# Configuration
$DOCKERHUB_USER = "tsouche"
$IMAGE_NAME = "rust_dev_container"
$DOCKERFILE = "Dockerfile.rustdev"

# Required support files
$REQUIRED_FILES = @(
    "authorized_keys.template",
    "install_vscode_extensions.sh",
    "devcontainer.json"
)

# Validate version format
if ($Version -ne "latest" -and $Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "ERROR: Invalid version format '$Version'" -ForegroundColor Red
    Write-Host "Expected format: X.Y.Z (e.g., 0.5.2) or 'latest'"
    exit 1
}

$FULL_IMAGE = "${DOCKERHUB_USER}/${IMAGE_NAME}"

# Determine tags
if ($Version -eq "latest") {
    $TAGS = @("latest")
    Write-Host "`n================================" -ForegroundColor Blue
    Write-Host "  Build Rust Dev Image" -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Image: $FULL_IMAGE"
    Write-Host "Version: latest"
    Write-Host "Tags: latest"
} else {
    $VERSION_TAG = "v${Version}"
    $MAJOR_MINOR = $Version -replace '(\d+\.\d+)\.\d+', '$1'
    $MINOR_TAG = "v${MAJOR_MINOR}"
    
    $TAGS = @($VERSION_TAG, $MINOR_TAG, "latest")
    
    Write-Host "`n================================" -ForegroundColor Blue
    Write-Host "  Build Rust Dev Image" -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Image: $FULL_IMAGE"
    Write-Host "Version: $Version"
    Write-Host "Tags: $VERSION_TAG, $MINOR_TAG, latest"
}
Write-Host ""

# Check required files
Write-Host "[1/5] Verifying required files..." -ForegroundColor Yellow
foreach ($file in $REQUIRED_FILES) {
    if (-not (Test-Path $file)) {
        Write-Host "ERROR: Missing required file: $file" -ForegroundColor Red
        exit 1
    }
    Write-Host "OK $file" -ForegroundColor Green
}

if (-not (Test-Path $DOCKERFILE)) {
    Write-Host "ERROR: $DOCKERFILE not found" -ForegroundColor Red
    exit 1
}
Write-Host "OK $DOCKERFILE" -ForegroundColor Green
Write-Host ""

# Check Docker is running
Write-Host "[2/5] Checking Docker..." -ForegroundColor Yellow
try {
    docker info | Out-Null
    Write-Host "OK Docker is running" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker is not running" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Build image
Write-Host "[3/5] Building image..." -ForegroundColor Yellow
$BUILD_ARGS = @(
    "build",
    "-f", $DOCKERFILE
)

foreach ($tag in $TAGS) {
    $BUILD_ARGS += "-t"
    $BUILD_ARGS += "${FULL_IMAGE}:${tag}"
}

$BUILD_DATE = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$BUILD_ARGS += @(
    "--build-arg", "BUILD_DATE=$BUILD_DATE",
    "--build-arg", "RUST_VERSION=$Version",
    "."
)

& docker $BUILD_ARGS

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "OK Build successful" -ForegroundColor Green
Write-Host ""

# Check DockerHub login
Write-Host "[4/5] Checking DockerHub login..." -ForegroundColor Yellow
$dockerInfo = docker info 2>&1 | Out-String
if ($dockerInfo -match "Username:\s+$DOCKERHUB_USER") {
    Write-Host "OK Already logged in as $DOCKERHUB_USER" -ForegroundColor Green
} else {
    Write-Host "Not logged in. Please log in to DockerHub..." -ForegroundColor Yellow
    docker login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: DockerHub login failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "OK Successfully logged in to DockerHub" -ForegroundColor Green
}
Write-Host ""

# Push to DockerHub
Write-Host "[5/5] Pushing to DockerHub..." -ForegroundColor Yellow
foreach ($tag in $TAGS) {
    Write-Host "  Pushing ${FULL_IMAGE}:${tag}..." -ForegroundColor Cyan
    docker push "${FULL_IMAGE}:${tag}"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Push failed for tag $tag" -ForegroundColor Red
        exit 1
    }
}
Write-Host "OK Push successful" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "================================" -ForegroundColor Green
Write-Host "  Build Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Image published to DockerHub:"
foreach ($tag in $TAGS) {
    Write-Host "  docker pull ${FULL_IMAGE}:${tag}"
}
Write-Host ""
Write-Host "Local images:"
docker images $FULL_IMAGE
Write-Host ""
