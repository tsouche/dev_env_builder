################################################################################
# Development Environment Deployment Script - v0.7.0 (PowerShell)
# Deploys to local development laptop
################################################################################

param(
    [switch]$SkipCleanup = $false
)

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

function Write-Info-Custom {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
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
        
        # Use Start-Job with timeout to prevent hanging
        $job = Start-Job -ScriptBlock {
            param($HostName, $Port, $User, $IdentityFile)
            & ssh -o StrictHostKeyChecking=no `
                  -o UserKnownHostsFile=nul `
                  -o ConnectTimeout=5 `
                  -o BatchMode=yes `
                  -o LogLevel=ERROR `
                  -i $IdentityFile `
                  -p $Port `
                  "$User@$HostName" `
                  "echo 'SSH_CONNECTION_OK'" 2>&1
        } -ArgumentList $HostName, $Port, $User, $IdentityFile
        
        # Wait for job with 10 second timeout
        $completed = Wait-Job -Job $job -Timeout 10
        
        if ($completed) {
            $sshResult = Receive-Job -Job $job
            $exitCode = $job.State -eq 'Completed'
            
            if ($exitCode) {
                $outputString = $sshResult | Out-String
                if ($outputString -match "SSH_CONNECTION_OK") {
                    Remove-Job -Job $job -Force
                    Write-Success "SSH connection successful!"
                    Write-Host "  Connection verified: $User@$HostName`:$Port" -ForegroundColor Green
                    return $true
                }
            }
            Remove-Job -Job $job -Force
        } else {
            Write-Host "  Connection timeout after 10 seconds" -ForegroundColor Gray
            Stop-Job -Job $job
            Remove-Job -Job $job -Force
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

if (-not $env:ANTHROPIC_API_KEY -or $env:ANTHROPIC_API_KEY -eq "sk-ant-xxx...") {
    Write-Info-Custom "ANTHROPIC_API_KEY not set. Claude Code will use claude.ai subscription."
    Write-Info-Custom "Run 'claude login' inside the container to authenticate with your Pro/Max account."
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
# Cleanup Existing Environment
################################################################################

if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "Checking for existing Docker environment..." -ForegroundColor Cyan
    
    # Check if containers exist
    $existingContainers = docker ps -a --filter "name=dev-" --format "{{.Names}}" 2>$null
    
    if ($existingContainers) {
        Write-Host ""
        Write-Host "Existing Docker environment detected:" -ForegroundColor Yellow
        $existingContainers | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
        Write-Host ""
        Write-Host "The deployment will automatically clean up the existing environment." -ForegroundColor Cyan
        Write-Host "This will remove all containers, images, and data volumes." -ForegroundColor Yellow
        Write-Host ""
        
        $response = Read-Host "Continue with cleanup and deployment? (Y/n) [Y]"
        
        if ($response -and $response -ne "Y" -and $response -ne "y" -and $response -ne "") {
            Write-Host "Deployment cancelled." -ForegroundColor Red
            exit 0
        }
        
        Write-Host ""
        Write-Host "Running cleanup script..." -ForegroundColor Cyan
        & "$ScriptDir\cleanup.ps1" -SkipConfirmation
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Cleanup failed" -ForegroundColor Red
            exit 1
        }
        
        Write-Host ""
        Write-Host "Cleanup complete. Proceeding with deployment..." -ForegroundColor Green
        Start-Sleep -Seconds 2
    } else {
        Write-Host "No existing environment found. Proceeding with fresh deployment..." -ForegroundColor Green
    }
} else {
    Write-Host "[SKIP] Cleanup skipped (use -SkipCleanup:$false to enable)" -ForegroundColor Yellow
}

Write-Host ""

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
    "$env:VOLUME_TARGET_CACHE",
    # QMD & Claude directories (Windows bind mounts)
    "$env:VOLUME_QMD_MODELS",
    "$env:VOLUME_CLAUDE_CONFIG"
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

# Rust Development Environment v0.7.0 - Auto-generated
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
// MongoDB Initialization Script
// Auto-generated by deploy-dev.ps1 v0.7.0
// Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

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
# Update CLAUDE.md on persistent volume
################################################################################

# The Dockerfile copies CLAUDE.md.template into the image, but the bind mount
# for ~/.claude overlays it. Copy the template to the Windows volume so the
# container always has the latest version.
$claudeMdTemplate = Join-Path $ScriptDir "CLAUDE.md.template"
$claudeMdTarget = Join-Path $env:VOLUME_CLAUDE_CONFIG "CLAUDE.md"
if (Test-Path $claudeMdTemplate) {
    Copy-Item -Force $claudeMdTemplate $claudeMdTarget
    Write-Success "CLAUDE.md updated on persistent volume"
} else {
    Write-Warning-Custom "CLAUDE.md.template not found — skipping"
}

################################################################################
# Configure Claude Code MCP Integration
################################################################################

Write-Header "Configuring Claude Code MCP Integration"

# Check if symlink exists and points to correct location
$symlinkCheck = docker exec -u rustdev $env:CONTAINER_NAME bash -c "test -L ~/.claude.json && readlink ~/.claude.json" 2>$null

if ($symlinkCheck -ne "/home/rustdev/.claude/claude.json") {
    Write-Host "Setting up Claude configuration symlink for eternal persistence..." -ForegroundColor Yellow
    
    # Backup existing .claude.json if it exists and is not a symlink
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    docker exec -u rustdev $env:CONTAINER_NAME bash -c "if [ -f ~/.claude.json ] && [ ! -L ~/.claude.json ]; then cp ~/.claude.json ~/.claude.json.backup.$timestamp; fi"
    
    # Create the eternal claude.json file if it doesn't exist
    $claudeConfigPath = "$env:VOLUME_CLAUDE_CONFIG"
    $claudeJsonPath = Join-Path $claudeConfigPath "claude.json"
    
    if (-not (Test-Path $claudeJsonPath)) {
        Write-Host "Creating eternal Claude configuration with QMD MCP server..." -ForegroundColor Yellow
        
        # Read existing .claude.json from container if it exists
        $existingConfig = docker exec -u rustdev $env:CONTAINER_NAME bash -c "cat ~/.claude.json 2>/dev/null || echo ''"
        
        if ($existingConfig -and $existingConfig -ne "") {
            # Merge existing config with QMD MCP server
            Write-Host "Merging existing Claude configuration with QMD MCP server..." -ForegroundColor Gray
            $existingConfig | Out-File -FilePath $claudeJsonPath -Encoding UTF8
            
            # Add QMD to mcpServers if not present
            $configContent = Get-Content $claudeJsonPath -Raw | ConvertFrom-Json
            if (-not $configContent.mcpServers) {
                $configContent | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value @{} -Force
            }
            if (-not $configContent.mcpServers.qmd) {
                $configContent.mcpServers | Add-Member -MemberType NoteProperty -Name "qmd" -Value @{"command"="qmd"; "args"=@("mcp")} -Force
            }
            $configContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $claudeJsonPath -Encoding UTF8
        } else {
            # Create fresh config with QMD MCP server
            $claudeConfig = @"
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["mcp"]
    }
  },
  "enabledMcpjsonServers": []
}
"@
            $claudeConfig | Out-File -FilePath $claudeJsonPath -Encoding UTF8
        }
        
        Write-Success "Eternal Claude configuration created: $claudeJsonPath"
    }
    
    # Create symlink from ~/.claude.json to eternal location
    docker exec -u rustdev $env:CONTAINER_NAME bash -c "ln -sf ~/.claude/claude.json ~/.claude.json"
    Write-Success "Symlink created: ~/.claude.json -> ~/.claude/claude.json"
} else {
    Write-Info-Custom "Claude configuration symlink already properly configured"
}

# Verify MCP configuration is present
$mcpCheck = docker exec -u rustdev $env:CONTAINER_NAME bash -c "grep -q '`"qmd`"' ~/.claude.json && echo 'QMD configured' || echo 'QMD missing'"
if ($mcpCheck -ne "QMD configured") {
    Write-Warning-Custom "QMD MCP server not found in configuration. Adding it..."
    # Use a simpler approach - create a temporary script file
    $tempScript = @"
import json
with open('.claude.json', 'r') as f:
    data = json.load(f)
data.setdefault('mcpServers', {})['qmd'] = {'command': 'qmd', 'args': ['mcp']}
with open('.claude.json', 'w') as f:
    json.dump(data, f, indent=2)
"@
    $tempScript | Out-File -FilePath "temp_mcp_fix.py" -Encoding UTF8
    docker cp "temp_mcp_fix.py" "$($env:CONTAINER_NAME):/home/rustdev/temp_mcp_fix.py"
    docker exec -u rustdev $env:CONTAINER_NAME python3 /home/rustdev/temp_mcp_fix.py
    Remove-Item "temp_mcp_fix.py" -Force
    docker exec -u rustdev $env:CONTAINER_NAME rm /home/rustdev/temp_mcp_fix.py
    Write-Success "QMD MCP server added to Claude configuration"
} else {
    Write-Success "QMD MCP server is properly configured"
}

# Validate QMD MCP integration
Write-Host "Validating QMD MCP integration..." -ForegroundColor Gray
$mcpValidation = docker exec -u rustdev $env:CONTAINER_NAME bash -c "
if command -v qmd &> /dev/null; then
    echo 'QMD installed'
else
    echo 'QMD missing'
    exit 1
fi

if qmd status &> /dev/null; then
    echo 'QMD functional'
else
    echo 'QMD broken'
    exit 1
fi

echo 'MCP ready'
" 2>&1

if ($mcpValidation -contains "QMD installed" -and $mcpValidation -contains "QMD functional" -and $mcpValidation -contains "MCP ready") {
    Write-Success "QMD MCP integration validated"
} else {
    Write-Warning-Custom "QMD MCP integration validation failed. Details: $mcpValidation"
}

Write-Host ""

################################################################################
# Clean up SSH Host Keys
################################################################################

Write-Header "Cleaning up SSH Host Keys"

# Remove old SSH host keys for localhost:2222 to avoid 'host key changed' warnings
$knownHostsPath = "$env:USERPROFILE\.ssh\known_hosts"
if (Test-Path $knownHostsPath) {
    Write-Host "Removing old SSH host keys from known_hosts..." -ForegroundColor Yellow
    # Check if key exists before trying to remove it
    $keyExists = & ssh-keygen -F "[localhost]:$($env:SSH_PORT)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        & ssh-keygen -R "[localhost]:$($env:SSH_PORT)" 2>&1 | Out-Null
        Write-Success "Old SSH host keys removed"
    } else {
        Write-Info-Custom "No existing SSH key for [localhost]:$($env:SSH_PORT) - nothing to remove"
    }
} else {
    Write-Info-Custom "No existing known_hosts file found - skipping key cleanup"
}

Write-Host ""

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
# Initialize QMD (Automated)
################################################################################

Write-Header "Initializing QMD Search Engine"

# First, ensure directory structure exists with proper permissions
Write-Host "Creating QMD directory structure and fixing permissions..." -ForegroundColor Yellow
# Fix ownership on .cache/qmd (includes models bind mount)
docker exec -u root $env:CONTAINER_NAME bash -c "mkdir -p /home/rustdev/.cache/qmd && chown -R 1026:110 /home/rustdev/.cache"
# Fix ownership on models directory (bind mount may be created as root)
docker exec -u root $env:CONTAINER_NAME bash -c "chown -R 1026:110 /home/rustdev/.cache/qmd/models"
Write-Success "Directory structure created with proper permissions"

Write-Host "Running QMD auto-initialization..." -ForegroundColor Yellow
Write-Host "  This runs the idempotent init_qmd.sh script automatically." -ForegroundColor Gray
Write-Host "  - First run: Downloads models (~2GB) and creates index" -ForegroundColor Gray
Write-Host "  - Subsequent runs: Updates existing index if workspace changed" -ForegroundColor Gray
Write-Host ""

# Trigger model download explicitly if models don't exist
$modelCheckResult = docker exec -u rustdev $env:CONTAINER_NAME bash -c "ls ~/.cache/qmd/models/*.gguf 2>/dev/null | wc -l" 2>$null
if ([int]$modelCheckResult -eq 0) {
    Write-Host "Downloading QMD GGUF models (~2GB, one-time download)..." -ForegroundColor Cyan
    Write-Host "  This may take 2-5 minutes depending on your internet connection." -ForegroundColor Gray
    Write-Host ""
    try {
        # Trigger model download by running a test embedding
        docker exec -u rustdev $env:CONTAINER_NAME bash -c "cd /workspace && echo '# Test' > /tmp/test.md && qmd collection add /tmp/test.md --name temp_init && qmd collection remove temp_init && rm /tmp/test.md" 2>&1 | Out-Null
        Write-Success "GGUF models downloaded successfully"
    } catch {
        Write-Warning-Custom "Model download may still be in progress. QMD will complete on first use."
    }
} else {
    Write-Success "GGUF models already present (reusing from previous deployment)"
}

Write-Host ""

try {
    # Run init_qmd.sh inside the container as rustdev user
    docker exec -u rustdev $env:CONTAINER_NAME bash -c "~/init_qmd.sh"
    Write-Success "QMD initialization completed"
    Write-Host ""
    Write-Host "✅ QMD is ready! Claude Code will automatically use it for searches." -ForegroundColor Green
} catch {
    Write-Warning-Custom "QMD initialization encountered an issue: $_"
    Write-Host "   QMD will auto-initialize on first shell login instead." -ForegroundColor Yellow
}

Write-Host ""

################################################################################
# Initialize gstack (Claude Code Skills Framework)
################################################################################

Write-Header "Initializing gstack Skills Framework"

# Ensure .claude/skills directory exists with proper permissions
Write-Host "Preparing gstack directory structure..." -ForegroundColor Yellow
docker exec -u root $env:CONTAINER_NAME bash -c "mkdir -p /home/rustdev/.claude/skills && chown -R 1026:110 /home/rustdev/.claude"
Write-Success "Directory structure ready"

Write-Host "Running gstack initialization..." -ForegroundColor Yellow
Write-Host "  This runs the idempotent init_gstack.sh script." -ForegroundColor Gray
Write-Host "  - First run: Clones gstack repo and runs setup" -ForegroundColor Gray
Write-Host "  - Subsequent runs: Updates to latest version" -ForegroundColor Gray
Write-Host ""

try {
    # Run init_gstack.sh inside the container as rustdev user
    docker exec -u rustdev $env:CONTAINER_NAME bash -c "~/init_gstack.sh"
    Write-Success "gstack initialization completed"
    Write-Host ""
    Write-Host "`u{2705} gstack is ready! Use /office-hours, /review, /browse, etc. in Claude Code." -ForegroundColor Green
} catch {
    Write-Warning-Custom "gstack initialization encountered an issue: $_"
    Write-Host "   Run manually inside container: ~/init_gstack.sh" -ForegroundColor Yellow
}

Write-Host ""

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
Write-Host "  9. Use Claude Code (CLI):" -ForegroundColor Blue
Write-Host "     Type 'claude' in the terminal to start the AI agent."
Write-Host "  10. Use Claude Chat:" -ForegroundColor Blue
Write-Host "      Open the Claude extension icon on the left sidebar."
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
