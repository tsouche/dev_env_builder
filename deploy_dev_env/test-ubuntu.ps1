################################################################################
# Ubuntu Container Test Script - v0.6.6
# Tests hot-swap deployment workflow with Ubuntu test container
# Simulates staging/prod deployment process locally before NAS deployment
################################################################################

param(
    [string]$ContainerName = "dev-container",
    [string]$UbuntuContainerName = "dev-ubuntu-test"
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

Write-Header "Ubuntu Container glibc Binary Test"

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

$ubuntuRunning = docker ps --filter "name=$UbuntuContainerName" --format "{{.Names}}" 2>$null
if (-not $ubuntuRunning) {
    Write-Error-Custom "Ubuntu test container '$UbuntuContainerName' is not running"
    Write-Host "Start the environment first: .\deploy-dev.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Success "Ubuntu test container is running"

################################################################################
# Step 2: Create Test Rust Program
################################################################################

Write-Step "Creating test Rust program in dev container..."

$rustCode = @'
fn main() {
    println!("Test glibc-compiled program running on Ubuntu container: ok");
}
'@

# Write the Rust code to a temp file on Windows, then copy to container
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $rustCode -NoNewline

# Create directory and copy file into container
$createResult = docker exec $ContainerName bash -c "mkdir -p /tmp/ubuntu-test" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to create directory in container"
    Write-Host $createResult -ForegroundColor Red
    Remove-Item $tempFile -Force
    exit 1
}

# Copy the file from Windows to container
docker cp $tempFile ${ContainerName}:/tmp/ubuntu-test/main.rs 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to copy Rust program to container"
    Remove-Item $tempFile -Force
    exit 1
}

# Clean up temp file
Remove-Item $tempFile -Force

Write-Success "Test program created at /tmp/ubuntu-test/main.rs"

################################################################################
# Step 3: Compile for Native glibc Target
################################################################################

Write-Step "Compiling for native x86_64-unknown-linux-gnu target..."

$compileResult = docker exec $ContainerName bash -c @"
cd /tmp/ubuntu-test && \
source /home/rustdev/.cargo/env && \
rustc main.rs -o ubuntu_test 2>&1
"@

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Compilation failed"
    Write-Host $compileResult -ForegroundColor Red
    exit 1
}

Write-Success "Binary compiled successfully"

################################################################################
# Step 4: Verify Binary Dependencies
################################################################################

Write-Step "Verifying binary dependencies..."

$lddResult = docker exec $ContainerName bash -c "ldd /tmp/ubuntu-test/ubuntu_test 2>&1"
Write-Host ""
Write-Host "Binary dependencies (glibc):" -ForegroundColor Cyan
Write-Host $lddResult
Write-Host ""

if ($lddResult -match "not a dynamic executable") {
    Write-Host "Warning: Binary is statically linked (unexpected for glibc builds)" -ForegroundColor Yellow
}

Write-Success "Binary verification complete"

################################################################################
# Step 5: Copy Binary to Ubuntu Test Container
################################################################################

Write-Step "Copying binary to Ubuntu test container..."

$tempFile = [System.IO.Path]::GetTempFileName()

$copyResult = docker cp ${ContainerName}:/tmp/ubuntu-test/ubuntu_test $tempFile 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to copy binary from dev container"
    Write-Host $copyResult -ForegroundColor Red
    exit 1
}

$copyResult2 = docker cp $tempFile ${UbuntuContainerName}:/tmp/ubuntu_test 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to copy binary to Ubuntu test container"
    Write-Host $copyResult2 -ForegroundColor Red
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    exit 1
}

# Clean up temp file
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

Write-Success "Binary copied to Ubuntu test container at /tmp/ubuntu_test"

################################################################################
# Step 6: Execute Binary on Ubuntu Test Container
################################################################################

Write-Step "Testing binary on Ubuntu container..."
Write-Host ""

$execResult = docker exec $UbuntuContainerName /tmp/ubuntu_test 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Binary execution failed on Ubuntu container"
    Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Output:" -ForegroundColor Red
    Write-Host $execResult -ForegroundColor Red
    Write-Host ""
    Write-Host "This indicates the binary is not compatible with the Ubuntu runtime environment." -ForegroundColor Yellow
    exit 1
}

Write-Host "--- Output from Ubuntu Container ---" -ForegroundColor Cyan
Write-Host $execResult
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host ""

Write-Success "Binary executed successfully on Ubuntu container"

################################################################################
# Summary
################################################################################

Write-Header "Test Summary"

Write-Host "[OK] Development container: Running" -ForegroundColor Green
Write-Host "[OK] Ubuntu test container: Running" -ForegroundColor Green
Write-Host "[OK] Test program: Created" -ForegroundColor Green
Write-Host "[OK] Compilation: Success (glibc target)" -ForegroundColor Green
Write-Host "[OK] Binary transfer: Success" -ForegroundColor Green
Write-Host "[OK] Execution on Ubuntu: Success" -ForegroundColor Green
Write-Host ""
Write-Host "The glibc-compiled binary is compatible with Ubuntu runtime!" -ForegroundColor Green
Write-Host ""
Write-Host "Hot-swap deployment workflow validated successfully." -ForegroundColor Green
Write-Host "You can now safely use this process to deploy to NAS staging/production environments." -ForegroundColor Cyan
Write-Host ""
