################################################################################
# Alpine Container Test Script - v0.6.5
# Tests musl-compiled Rust binaries on the Alpine container
################################################################################

param(
    [string]$ContainerName = "dev-container",
    [string]$AlpineContainerName = "dev-alpine-test"
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] $Message" -ForegroundColor Yellow
}

Write-Header "Alpine Container Musl Binary Test"

################################################################################
# Step 1: Verify Containers Are Running
################################################################################

Write-Step "Verifying containers are running..."

$devRunning = docker ps --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
if (-not $devRunning) {
    Write-Error-Custom "Dev container '$ContainerName' is not running"
    Write-Host "Start the environment first: .\deploy-dev.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Success "Dev container is running"

$alpineRunning = docker ps --filter "name=$AlpineContainerName" --format "{{.Names}}" 2>$null
if (-not $alpineRunning) {
    Write-Error-Custom "Alpine container '$AlpineContainerName' is not running"
    Write-Host "Start the environment first: .\deploy-dev.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Success "Alpine container is running"

################################################################################
# Step 2: Create Test Rust Program
################################################################################

Write-Step "Creating test Rust program in dev container..."

$rustCode = @'
fn main() {
    println!("Test musl-compiled program running on Alpine container: ok");
}
'@

# Write the Rust code to a temp file on Windows, then copy to container
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $rustCode -NoNewline

# Create directory and copy file into container
$createResult = docker exec $ContainerName bash -c "mkdir -p /tmp/alpine-test" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to create directory in container"
    Write-Host $createResult -ForegroundColor Red
    Remove-Item $tempFile -Force
    exit 1
}

# Copy the file from Windows to container
docker cp $tempFile ${ContainerName}:/tmp/alpine-test/main.rs 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to copy Rust program to container"
    Remove-Item $tempFile -Force
    exit 1
}

# Clean up temp file
Remove-Item $tempFile -Force

Write-Success "Test program created at /tmp/alpine-test/main.rs"

################################################################################
# Step 3: Compile for musl Target
################################################################################

Write-Step "Compiling for x86_64-unknown-linux-musl target..."

$compileResult = docker exec $ContainerName bash -c "cd /tmp/alpine-test && rustc --target x86_64-unknown-linux-musl main.rs -o alpine_test 2>&1"

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Compilation failed"
    Write-Host $compileResult -ForegroundColor Red
    exit 1
}
Write-Success "Binary compiled successfully"

################################################################################
# Step 4: Copy Binary to Alpine Container
################################################################################

Write-Step "Copying binary to Alpine container..."

# Copy from dev container to Windows temp, then to Alpine container
$tempBinary = Join-Path $env:TEMP "alpine_test"

docker cp ${ContainerName}:/tmp/alpine-test/alpine_test $tempBinary 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to copy binary from dev container"
    exit 1
}

docker cp $tempBinary ${AlpineContainerName}:/tmp/alpine_test 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to copy binary to Alpine container"
    Remove-Item $tempBinary -Force -ErrorAction SilentlyContinue
    exit 1
}

# Clean up temp file on Windows
Remove-Item $tempBinary -Force -ErrorAction SilentlyContinue

Write-Success "Binary copied to Alpine container at /tmp/alpine_test"

################################################################################
# Step 5: Execute Binary on Alpine
################################################################################

Write-Step "Testing binary on Alpine Linux..."

$execResult = docker exec $AlpineContainerName /tmp/alpine_test 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Binary execution failed"
    Write-Host $execResult -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Output from Alpine container:" -ForegroundColor Cyan
Write-Host "  $execResult" -ForegroundColor White
Write-Host ""

################################################################################
# Step 6: Verify Output
################################################################################

Write-Step "Verifying output..."

$expectedOutput = "Test musl-compiled program running on Alpine container: ok"
if ($execResult -match [regex]::Escape($expectedOutput)) {
    Write-Success "Output verification passed!"
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Alpine Container Test: SUCCESS" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Blue
    Write-Host "  - Rust program created and compiled with musl target" -ForegroundColor White
    Write-Host "  - Binary successfully executed on Alpine Linux 3.19" -ForegroundColor White
    Write-Host "  - Docker CLI working correctly for container-to-container operations" -ForegroundColor White
    Write-Host ""
    Write-Host "The musl cross-compilation toolchain is functioning properly!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Error-Custom "Output verification failed"
    Write-Host "Expected: $expectedOutput" -ForegroundColor Yellow
    Write-Host "Got:      $execResult" -ForegroundColor Yellow
    exit 1
}

################################################################################
# Cleanup Notification
################################################################################

Write-Host "Test files remain in /tmp/alpine-test" -ForegroundColor Gray
Write-Host "To clean up manually:" -ForegroundColor Gray
Write-Host "  docker exec $ContainerName rm -rf /tmp/alpine-test" -ForegroundColor Gray
Write-Host "  docker exec $AlpineContainerName rm /tmp/alpine_test" -ForegroundColor Gray
Write-Host ""
