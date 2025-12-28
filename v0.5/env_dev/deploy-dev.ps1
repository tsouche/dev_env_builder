################################################################################
# Development Environment Deployment Script - v0.5.6 (PowerShell)
# Deploys to local development laptop
################################################################################

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
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

function Test-SSHConnection {
    param(
        [string]$HostName = "localhost",
        [int]$Port = 2222,
        [string]$User = "rustdev",
        [string]$IdentityFile,
        [int]$MaxRetries = 5,
        [int]$RetryDelay = 2
    )
    
    Write-Host ""
    Write-Host "Testing SSH connectivity to $User@$HostName`:$Port..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Host "  Attempt $i of $MaxRetries..." -ForegroundColor Gray
        
        $sshResult = & ssh -o StrictHostKeyChecking=no `
                           -o UserKnownHostsFile=nul `
                           -o ConnectTimeout=5 `
                           -o BatchMode=yes `
                           -o LogLevel=ERROR `
                           -i $IdentityFile `
                           -p $Port `
                           "$User@$HostName" `
                           "echo 'SSH_CONNECTION_OK'" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $outputString = $sshResult | Out-String
            if ($outputString -match "SSH_CONNECTION_OK") {
                Write-Success "SSH connection successful!"
                Write-Host "  Connection verified: $User@$HostName`:$Port" -ForegroundColor Green
                return $true
            }
        }
        
        if ($i -lt $MaxRetries) {
            Start-Sleep -Seconds $RetryDelay
        }
    }
    
    Write-Host "[ERROR] SSH connection failed after $MaxRetries attempts" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check container is running: docker ps --filter name=$($env:CONTAINER_NAME)" -ForegroundColor White
    Write-Host "  2. Check container logs: docker logs $($env:CONTAINER_NAME)" -ForegroundColor White
    Write-Host "  3. Verify SSH key: ssh-keygen -lf $IdentityFile" -ForegroundColor White
    Write-Host "  4. Test manually: ssh -i $IdentityFile -p $Port $User@$HostName" -ForegroundColor White
    Write-Host ""
    return $false
}

function Show-SSHKeyInfo {
    param(
        [string]$PublicKeyPath,
        [string]$PrivateKeyPath
    )
    
    if (Test-Path $PublicKeyPath) {
        Write-Host ""
        Write-Host "SSH Key Information:" -ForegroundColor Cyan
        Write-Host "  Public key:  $PublicKeyPath" -ForegroundColor White
        Write-Host "  Private key: $PrivateKeyPath" -ForegroundColor White
        
        try {
            $fingerprint = & ssh-keygen -lf $PublicKeyPath 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Fingerprint: $fingerprint" -ForegroundColor White
            }
        } catch {
            Write-Host "  (Unable to get fingerprint)" -ForegroundColor Gray
        }
    }
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

$ProjectDir = if ($env:PROJECT_DIR) { $env:PROJECT_DIR } else { "rust_project" }
$DbName = if ($env:DB_NAME) { $env:DB_NAME } else { "rust_app_db" }
$DbUser = if ($env:DB_USER) { $env:DB_USER } else { "app_user" }
$DbPassword = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "app_password" }
$Collection1 = if ($env:COLLECTION_1) { $env:COLLECTION_1 } else { "items" }
$Collection2 = if ($env:COLLECTION_2) { $env:COLLECTION_2 } else { "users" }
$Collection3 = if ($env:COLLECTION_3) { $env:COLLECTION_3 } else { "data" }

Write-Header "Development Environment Deployment"

################################################################################
# Check for Existing Project Directory
################################################################################

$existingProjectPath = Join-Path $env:PROJECT_PATH $ProjectDir
if (Test-Path $existingProjectPath) {
    Write-Host ""
    Write-Warning-Custom "Existing project directory found: $existingProjectPath"
    Write-Host ""
    Write-Host "This directory will be mounted to the container and may contain old files." -ForegroundColor Yellow
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Keep existing directory" -ForegroundColor White
    Write-Host "  2. Delete and start fresh (default)" -ForegroundColor White
    Write-Host "  3. Cancel deployment" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "Enter choice (1/2/3) [2]"
    
    if ($choice -eq "3") {
        Write-Host "Deployment cancelled." -ForegroundColor Red
        exit 0
    }
    elseif ($choice -eq "1") {
        Write-Success "Keeping existing project directory"
    }
    else {
        Write-Host "Deleting existing project directory..." -ForegroundColor Yellow
        Remove-Item -Path $existingProjectPath -Recurse -Force
        Write-Success "Project directory deleted"
    }
    Write-Host ""
}

################################################################################
# Create Directories
################################################################################

Write-Header "Creating Directory Structure"
$directories = @(
    "$env:PROJECT_PATH",
    "$env:VOLUME_MONGODB_DATA",
    "$env:VOLUME_MONGODB_INIT",
    # Commented out since these volumes are no longer mounted
    # "$env:VOLUME_CARGO_CACHE",
    # "$env:VOLUME_CARGO_GIT_CACHE",
    # "$env:VOLUME_RUSTUP_CACHE",
    "$env:VOLUME_TARGET_CACHE"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Success "Directories created"

Write-Host ""
Write-Host "NOTE:" -ForegroundColor Yellow
Write-Host "  The project directory will NOT be pre-created." -ForegroundColor Yellow
Write-Host "  You should clone the repository from within VS Code after connecting." -ForegroundColor Yellow
Write-Host ""

################################################################################
# SSH Key Setup
################################################################################

Write-Header "Configuring SSH Authentication"

# Check for existing SSH keys
$sshKeySource = $null
$sshPrivateKey = $null
$sshKeyPaths = @(
    @{Public="$env:USERPROFILE\.ssh\id_ed25519.pub"; Private="$env:USERPROFILE\.ssh\id_ed25519"},
    @{Public="$env:USERPROFILE\.ssh\id_rsa.pub"; Private="$env:USERPROFILE\.ssh\id_rsa"}
)

foreach ($keyPair in $sshKeyPaths) {
    if (Test-Path $keyPair.Public) {
        $sshKeySource = $keyPair.Public
        $sshPrivateKey = $keyPair.Private
        Write-Success "Found existing SSH key: $sshKeySource"
        break
    }
}

# Generate new key if none exists
if ($null -eq $sshKeySource) {
    Write-Warning-Custom "No SSH key found. Generating new ed25519 key..."
    
    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    
    $sshPrivateKey = "$sshDir\id_ed25519"
    $sshKeySource = "$sshDir\id_ed25519.pub"
    
    # Generate key using ssh-keygen
    $email = "$env:USERNAME@$env:COMPUTERNAME"
    & ssh-keygen -t ed25519 -f $sshPrivateKey -N '""' -C $email
    
    if ($LASTEXITCODE -eq 0 -and (Test-Path $sshKeySource)) {
        Write-Success "SSH key generated: $sshPrivateKey"
    } else {
        Write-Host "[ERROR] Failed to generate SSH key" -ForegroundColor Red
        Write-Host "Please install OpenSSH client or generate a key manually:" -ForegroundColor Yellow
        Write-Host "  ssh-keygen -t ed25519 -C 'your_email@example.com'" -ForegroundColor Yellow
        exit 1
    }
}

# Copy public key to authorized_keys
Copy-Item $sshKeySource "$ScriptDir\authorized_keys" -Force
Write-Success "Configured SSH authentication with key: $sshKeySource"

# Display SSH key information
Show-SSHKeyInfo -PublicKeyPath $sshKeySource -PrivateKeyPath $sshPrivateKey

################################################################################
# Configure SSH Config for VS Code
################################################################################

Write-Header "Configuring VS Code SSH Connection"

$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$sshConfigDir = Split-Path $sshConfigPath -Parent

# Ensure .ssh directory exists
if (-not (Test-Path $sshConfigDir)) {
    New-Item -ItemType Directory -Path $sshConfigDir -Force | Out-Null
}

# Read existing config or create empty
$existingConfig = ""
if (Test-Path $sshConfigPath) {
    $existingConfig = Get-Content $sshConfigPath -Raw
}

# Check if rust-dev host already exists
if ($existingConfig -notmatch "Host rust-dev") {
    # Prepare the new host configuration
    $newHostConfig = @"

# Rust Development Environment v0.5.6 - Auto-generated
Host rust-dev
    HostName localhost
    Port $($env:SSH_PORT)
    User $($env:USERNAME)
    IdentityFile $($sshPrivateKey -replace '\\','/')
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

"@
    
    # Append to config file
    Add-Content -Path $sshConfigPath -Value $newHostConfig
    Write-Success "Added 'rust-dev' to SSH config: $sshConfigPath"
} else {
    Write-Success "SSH config 'rust-dev' already exists in: $sshConfigPath"
}

################################################################################
# MongoDB Init Script
################################################################################

Write-Header "Creating MongoDB Initialization Script"

$mongoInitScript = @"
db = db.getSiblingDB('$DbName');

db.createUser({
    user: '$DbUser',
    pwd: '$DbPassword',
    roles: [
        {
            role: 'readWrite',
            db: '$DbName'
        }
    ]
});

db.createCollection('$Collection1');
db.createCollection('$Collection2');
db.createCollection('$Collection3');

print('Database initialized: $DbName');
"@

# Write directly to env_dev directory
$mongoInitScript | Out-File -FilePath "$ScriptDir\01-init-db.js" -Encoding UTF8

# Copy to the mounted volume location
Copy-Item "$ScriptDir\01-init-db.js" "$env:VOLUME_MONGODB_INIT\01-init-db.js" -Force

Write-Success "MongoDB init script created and copied to volume location"

################################################################################
# Create Sample Project
################################################################################

Write-Header "Skipping Sample Project Creation"
Write-Host "The actual project should be cloned from git repository:" -ForegroundColor Yellow
Write-Host "  Repository: $($env:GIT_REPO)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Clone the repository after connecting to the container via VS Code." -ForegroundColor Yellow
Write-Host ""

################################################################################
# Build and Deploy
################################################################################

Write-Header "Building Docker Images"
docker-compose -f docker-compose-dev.yml build
Write-Success "Images built"

Write-Header "Starting Services"
docker-compose -f docker-compose-dev.yml up -d
Write-Success "Services started"

Write-Host "Waiting for containers to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

################################################################################
# Test SSH Connectivity
################################################################################

Write-Header "Verifying SSH Connection"

$sshTestPassed = Test-SSHConnection `
    -HostName "localhost" `
    -Port $env:SSH_PORT `
    -User $env:USERNAME `
    -IdentityFile $sshPrivateKey `
    -MaxRetries 5 `
    -RetryDelay 3

if (-not $sshTestPassed) {
    Write-Host ""
    Write-Warning-Custom "SSH connectivity test failed, but continuing deployment."
    Write-Host "You may need to troubleshoot the connection manually." -ForegroundColor Yellow
    Write-Host ""
}

################################################################################
# Display Status
################################################################################

Write-Header "Deployment Complete - Development Environment"
docker-compose -f docker-compose-dev.yml ps

Write-Host ""
Write-Success "Development environment is ready!"
Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Blue
Write-Host "  - SSH Access:        localhost:$($env:SSH_PORT) (user: $($env:USERNAME))"
Write-Host "  - Application:       http://localhost:$($env:APP_PORT)"
Write-Host "  - MongoDB:           localhost:$($env:MONGO_PORT)"
Write-Host "  - Mongo Express:     http://localhost:$($env:MONGO_EXPRESS_PORT)"
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Blue
Write-Host "  - Environment:       DEV"
Write-Host "  - Container:         $($env:CONTAINER_NAME)"
Write-Host "  - Workspace:         /workspace"
Write-Host "  - Project Path:      $($env:PROJECT_PATH)"
Write-Host "  - Database:          $DbName"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Blue
Write-Host "  1. In VS Code, press Ctrl+Shift+P"
Write-Host "  2. Type 'Remote-SSH: Connect to Host'"
Write-Host "  3. Select 'rust-dev'"
Write-Host "  4. Open folder: /workspace"
Write-Host "  5. Clone repository: $($env:GIT_REPO)"
Write-Host "     git clone $($env:GIT_REPO)"
Write-Host "  6. Open terminal (Ctrl+`) - Extensions will auto-install!"
Write-Host "  7. Open the cloned project: /workspace/$ProjectDir"
Write-Host "  8. Run: cargo build"
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "  Clone the repository FROM WITHIN the container (via VS Code terminal)" -ForegroundColor Yellow
Write-Host "  DO NOT clone on Windows and mount it - this causes WSL mount issues!" -ForegroundColor Yellow
Write-Host ""
Write-Host "SSH Configuration:" -ForegroundColor Blue
Write-Host "  - Host alias:        rust-dev"
Write-Host "  - Config file:       $env:USERPROFILE\.ssh\config"
Write-Host "  - Identity file:     $sshPrivateKey"
Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor Blue
Write-Host "  - Logs:      docker-compose -f docker-compose-dev.yml logs -f"
Write-Host "  - Stop:      docker-compose -f docker-compose-dev.yml down"
Write-Host "  - Restart:   docker-compose -f docker-compose-dev.yml restart"
Write-Host "  - Shell:     docker-compose -f docker-compose-dev.yml exec dev-container bash"
Write-Host ""
