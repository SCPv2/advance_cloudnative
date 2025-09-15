# Samsung Cloud Platform v2 - Kubernetes Configuration Manager (PowerShell)
# Processes user input variables and applies them to Kubernetes deployment files
#
# Usage:
#   .\k8s_config_manager.ps1                    # Apply user variables to k8s files
#   .\k8s_config_manager.ps1 -Reset             # Reset k8s files to template defaults
#   .\k8s_config_manager.ps1 -Debug             # Enable debug output
#
# This script reads variables.json and applies user input values to k8s deployment files
# Author: SCPv2 Team

param(
    [switch]$Debug,
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$VariablesJson = Join-Path $ScriptDir "variables.json"
$K8sAppDir = Join-Path $ProjectDir "k8s_app_deployment"

# Color functions
function Red($text) { Write-Host $text -ForegroundColor Red }
function Green($text) { Write-Host $text -ForegroundColor Green }
function Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Blue($text) { Write-Host $text -ForegroundColor Blue }
function Cyan($text) { Write-Host $text -ForegroundColor Cyan }

# Logging functions
function Write-Info($message) { Write-Host "[INFO] $message" }
function Write-Success($message) { Green "[SUCCESS] $message" }
function Write-Error($message) { Red "[ERROR] $message" }
function Write-Warning($message) { Yellow "[WARNING] $message" }

# Template marker definitions
$global:TemplateMarkers = @{
    "PRIVATE_DOMAIN_NAME" = "{{PRIVATE_DOMAIN_NAME}}"
    "PUBLIC_DOMAIN_NAME" = "{{PUBLIC_DOMAIN_NAME}}"
    "USER_PUBLIC_IP" = "{{USER_PUBLIC_IP}}"
    "KEYPAIR_NAME" = "{{KEYPAIR_NAME}}"
    "OBJECT_STORAGE_ACCESS_KEY" = "{{OBJECT_STORAGE_ACCESS_KEY}}"
    "OBJECT_STORAGE_SECRET_KEY" = "{{OBJECT_STORAGE_SECRET_KEY}}"
    "OBJECT_STORAGE_ENDPOINT" = "{{OBJECT_STORAGE_ENDPOINT}}"
    "OBJECT_STORAGE_BUCKET_NAME" = "{{OBJECT_STORAGE_BUCKET_NAME}}"
    "OBJECT_STORAGE_BUCKET_ID" = "{{OBJECT_STORAGE_BUCKET_ID}}"
    "CONTAINER_REGISTRY_ENDPOINT" = "{{CONTAINER_REGISTRY_ENDPOINT}}"
}

# Files that need template processing
$global:K8sTemplateFiles = @(
    @{
        Path = "k8s-manifests\configmap.yaml"
        Description = "ConfigMap with domain configuration"
    },
    @{
        Path = "k8s-manifests\app-deployment.yaml"
        Description = "App deployment with master_config.json"
    },
    @{
        Path = "k8s-manifests\external-db-service.yaml"
        Description = "External database service configuration"
    },
    @{
        Path = "nginx-ingress-controller.yaml"
        Description = "Nginx Ingress Controller with domain routing"
    },
    @{
        Path = "scripts\deploy.sh"
        Description = "Deployment script"
    },
    @{
        Path = "scripts\deploy-from-bastion.sh"
        Description = "Bastion deployment script"
    }
)

# Initialize directories and validate environment
function Initialize-Environment {
    Write-Info "🔧 Initializing Kubernetes Configuration Manager..."

    # Check if k8s_app_deployment directory exists
    if (!(Test-Path $K8sAppDir)) {
        Write-Error "Kubernetes application directory not found: $K8sAppDir"
        exit 1
    }

    # Create logs directory if needed
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }

    Write-Success "Environment initialized"
}

# Load variables from JSON file
function Get-UserVariables {
    Write-Info "📋 Loading user variables from variables.json..."

    if (!(Test-Path $VariablesJson)) {
        Write-Error "Variables JSON file not found: $VariablesJson"
        Write-Error "Please run variables_manager.ps1 first to generate variables.json"
        exit 1
    }

    try {
        $variables = Get-Content $VariablesJson | ConvertFrom-Json
        Write-Success "Loaded variables from JSON file"

        if ($Debug) {
            Write-Info "Variables loaded:"
            Write-Info "  Private Domain: $($variables.private_domain_name)"
            Write-Info "  Public Domain: $($variables.public_domain_name)"
            Write-Info "  Keypair: $($variables.keypair_name)"
            Write-Info "  User IP: $($variables.user_public_ip)"
        }

        return $variables
    }
    catch {
        Write-Error "Failed to parse variables.json: $($_.Exception.Message)"
        exit 1
    }
}

# Create template backup with default template values
function Backup-OriginalFile {
    param(
        [string]$FilePath
    )

    $backupPath = "$FilePath.template"

    # Only create template backup if it doesn't exist (preserve original template)
    if (!(Test-Path $backupPath) -and (Test-Path $FilePath)) {
        Copy-Item $FilePath $backupPath -Force
        Write-Info "Created template backup: $(Split-Path $backupPath -Leaf)"
    }
}

# Restore file from template backup
function Restore-FromTemplate {
    param(
        [string]$FilePath
    )

    $backupPath = "$FilePath.template"

    if (Test-Path $backupPath) {
        Copy-Item $backupPath $FilePath -Force
        Write-Info "Restored from template: $(Split-Path $FilePath -Leaf)"
        return $true
    }
    else {
        Write-Warning "Template backup not found: $(Split-Path $backupPath -Leaf)"
        return $false
    }
}

# Apply variable substitutions to file content
function Apply-VariableSubstitutions {
    param(
        [string]$Content,
        [object]$Variables
    )

    $processedContent = $Content

    # Apply each variable substitution from user_input_variables
    $processedContent = $processedContent -replace $global:TemplateMarkers["PRIVATE_DOMAIN_NAME"], $Variables.user_input_variables.private_domain_name
    $processedContent = $processedContent -replace $global:TemplateMarkers["PUBLIC_DOMAIN_NAME"], $Variables.user_input_variables.public_domain_name
    $processedContent = $processedContent -replace $global:TemplateMarkers["USER_PUBLIC_IP"], $Variables.user_input_variables.user_public_ip
    $processedContent = $processedContent -replace $global:TemplateMarkers["KEYPAIR_NAME"], $Variables.user_input_variables.keypair_name

    # Object storage variables from user_input_variables
    if ($Variables.user_input_variables.PSObject.Properties.Name -contains "object_storage_access_key_id") {
        $processedContent = $processedContent -replace $global:TemplateMarkers["OBJECT_STORAGE_ACCESS_KEY"], $Variables.user_input_variables.object_storage_access_key_id
    }
    if ($Variables.user_input_variables.PSObject.Properties.Name -contains "object_storage_secret_access_key") {
        $processedContent = $processedContent -replace $global:TemplateMarkers["OBJECT_STORAGE_SECRET_KEY"], $Variables.user_input_variables.object_storage_secret_access_key
    }

    # Object storage endpoint from ceweb_required_variables
    if ($Variables.ceweb_required_variables.PSObject.Properties.Name -contains "object_storage_private_endpoint") {
        $processedContent = $processedContent -replace $global:TemplateMarkers["OBJECT_STORAGE_ENDPOINT"], $Variables.ceweb_required_variables.object_storage_private_endpoint
    }
    if ($Variables.ceweb_required_variables.PSObject.Properties.Name -contains "object_storage_bucket_name") {
        $processedContent = $processedContent -replace $global:TemplateMarkers["OBJECT_STORAGE_BUCKET_NAME"], $Variables.ceweb_required_variables.object_storage_bucket_name
    }
    if ($Variables.user_input_variables.PSObject.Properties.Name -contains "object_storage_bucket_string") {
        $processedContent = $processedContent -replace $global:TemplateMarkers["OBJECT_STORAGE_BUCKET_ID"], $Variables.user_input_variables.object_storage_bucket_string
    }

    return $processedContent
}

# Process a single k8s template file
function Process-K8sTemplateFile {
    param(
        [object]$FileInfo,
        [object]$Variables
    )

    $filePath = Join-Path $K8sAppDir $FileInfo.Path
    $fileName = Split-Path $filePath -Leaf

    Write-Info "Processing: $fileName"

    if (!(Test-Path $filePath)) {
        Write-Warning "File not found, skipping: $filePath"
        return
    }

    try {
        # Create backup if it doesn't exist
        Backup-OriginalFile $filePath

        # Read template content
        $templatePath = "$filePath.template"
        if (Test-Path $templatePath) {
            $content = Get-Content $templatePath -Raw -Encoding UTF8
        }
        else {
            $content = Get-Content $filePath -Raw -Encoding UTF8
        }

        # Apply variable substitutions
        $processedContent = Apply-VariableSubstitutions $content $Variables

        # Write processed content back to file
        Set-Content $filePath -Value $processedContent -Encoding UTF8

        Write-Success "✅ Applied variables to: $fileName"

        if ($Debug) {
            Write-Info "  Template markers replaced in $fileName"
        }
    }
    catch {
        Write-Error "Failed to process $fileName`: $($_.Exception.Message)"
    }
}

# Apply user variables to all k8s template files
function Invoke-K8sTemplateProcessing {
    param([object]$Variables)

    Write-Info "🔄 Applying user variables to Kubernetes deployment files..."
    Write-Host ""

    foreach ($fileInfo in $global:K8sTemplateFiles) {
        Process-K8sTemplateFile $fileInfo $Variables
    }

    Write-Host ""
    Write-Success "🎉 All Kubernetes template files processed successfully!"
}

# Reset all k8s files to template defaults
function Invoke-K8sTemplateReset {
    Write-Info "🔄 Resetting Kubernetes deployment files to template defaults..."
    Write-Host ""

    $resetCount = 0

    foreach ($fileInfo in $global:K8sTemplateFiles) {
        $filePath = Join-Path $K8sAppDir $fileInfo.Path
        $fileName = Split-Path $filePath -Leaf

        Write-Info "Resetting: $fileName"

        if (Restore-FromTemplate $filePath) {
            $resetCount++
            Write-Success "✅ Reset to template: $fileName"
        }
        else {
            Write-Warning "⚠️  No template backup found: $fileName"
        }
    }

    Write-Host ""
    if ($resetCount -gt 0) {
        Write-Success "🎉 Reset $resetCount Kubernetes files to template defaults!"
    }
    else {
        Write-Warning "No files were reset (no template backups found)"
    }
}

# Show summary of template processing
function Show-ProcessingSummary {
    param([object]$Variables)

    Write-Host ""
    Cyan "================================================================"
    Cyan "KUBERNETES CONFIGURATION PROCESSING SUMMARY"
    Cyan "================================================================"
    Write-Host ""

    Write-Info "📊 Applied Variables:"
    Write-Info "  Private Domain: $($Variables.user_input_variables.private_domain_name)"
    Write-Info "  Public Domain: $($Variables.user_input_variables.public_domain_name)"
    Write-Info "  Keypair Name: $($Variables.user_input_variables.keypair_name)"
    Write-Info "  User Public IP: $($Variables.user_input_variables.user_public_ip)"

    if ($Variables.ceweb_required_variables.PSObject.Properties.Name -contains "object_storage_bucket_name") {
        Write-Info "  Object Storage Bucket: $($Variables.ceweb_required_variables.object_storage_bucket_name)"
    }

    Write-Host ""
    Write-Info "📁 Processed Files:"
    foreach ($fileInfo in $global:K8sTemplateFiles) {
        $filePath = Join-Path $K8sAppDir $fileInfo.Path
        if (Test-Path $filePath) {
            Write-Info "  ✅ $($fileInfo.Path) - $($fileInfo.Description)"
        }
        else {
            Write-Info "  ⚠️  $($fileInfo.Path) - File not found"
        }
    }

    Write-Host ""
    Write-Info "📝 Template Backups:"
    foreach ($fileInfo in $global:K8sTemplateFiles) {
        $filePath = Join-Path $K8sAppDir $fileInfo.Path
        $backupPath = "$filePath.template"
        if (Test-Path $backupPath) {
            Write-Info "  ✅ $($fileInfo.Path).template"
        }
        else {
            Write-Info "  ⚠️  $($fileInfo.Path).template - Backup missing"
        }
    }

    Write-Host ""
    Write-Info "📦 Generated Files:"
    $UserdataDir = Join-Path $ScriptDir "generated_userdata"
    $BastionUserdataFile = Join-Path $UserdataDir "userdata_bastion.sh"
    if (Test-Path $BastionUserdataFile) {
        Write-Info "  ✅ Bastion UserData: $BastionUserdataFile"
    }

    Write-Host ""
    Write-Success "🚀 Kubernetes deployment files are ready!"
    Write-Host ""
    Cyan "Next Steps:"
    Write-Host "  1. Use the generated bastion userdata in Terraform deployment"
    Write-Host "  2. Deploy infrastructure: terraform apply"
    Write-Host "  3. Bastion VM will auto-configure Kubernetes files"
    Write-Host "  4. Follow manual deployment steps in README.md"
}

# Generate bastion userdata for automatic k8s deployment
function New-BastionUserData {
    param($Variables)

    Write-Info "🏗️ Generating bastion userdata for automatic Kubernetes deployment..."

    # Create userdata directory
    $UserdataDir = Join-Path $ScriptDir "generated_userdata"
    if (!(Test-Path $UserdataDir)) {
        New-Item -ItemType Directory -Path $UserdataDir -Force | Out-Null
    }

    # Read setup-deployment.sh template
    $SetupScriptTemplate = Join-Path $K8sAppDir "setup-deployment.sh"
    if (!(Test-Path $SetupScriptTemplate)) {
        Write-Error "Setup script template not found: $SetupScriptTemplate"
        return $false
    }

    # Replace template markers with actual values
    $SetupScriptContent = Get-Content $SetupScriptTemplate -Raw

    # Apply user variables to setup script
    $SetupScriptContent = $SetupScriptContent -replace '\{\{PRIVATE_DOMAIN_NAME\}\}', $Variables.user_input_variables.private_domain_name
    $SetupScriptContent = $SetupScriptContent -replace '\{\{PUBLIC_DOMAIN_NAME\}\}', $Variables.user_input_variables.public_domain_name
    $SetupScriptContent = $SetupScriptContent -replace '\{\{OBJECT_STORAGE_ACCESS_KEY\}\}', $Variables.user_input_variables.object_storage_access_key_id
    $SetupScriptContent = $SetupScriptContent -replace '\{\{OBJECT_STORAGE_SECRET_KEY\}\}', $Variables.user_input_variables.object_storage_secret_access_key
    $SetupScriptContent = $SetupScriptContent -replace '\{\{OBJECT_STORAGE_BUCKET_ID\}\}', $Variables.user_input_variables.object_storage_bucket_string
    $SetupScriptContent = $SetupScriptContent -replace '\{\{CONTAINER_REGISTRY_ENDPOINT\}\}', $Variables.user_input_variables.container_registry_endpoint
    $SetupScriptContent = $SetupScriptContent -replace '\{\{USER_PUBLIC_IP\}\}', $Variables.user_input_variables.user_public_ip
    $SetupScriptContent = $SetupScriptContent -replace '\{\{KEYPAIR_NAME\}\}', $Variables.user_input_variables.keypair_name

    # Generate bastion userdata with comprehensive error handling
    $BastionUserData = @"
#!/bin/bash
# Samsung Cloud Platform v2 - Bastion Server UserData
# Auto-generated by k8s_config_manager.ps1
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

set -e

# Color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "`${BLUE}[INFO]`${NC} `$1"; }
log_success() { echo -e "`${GREEN}[SUCCESS]`${NC} `$1"; }
log_error() { echo -e "`${RED}[ERROR]`${NC} `$1"; }
log_warning() { echo -e "`${YELLOW}[WARNING]`${NC} `$1"; }

# Error handling function
handle_error() {
    local exit_code=`$?
    local line_number=`$1
    log_error "Script failed at line `$line_number with exit code `$exit_code"
    log_error "Check /var/log/cloud-init-output.log for detailed error information"
    echo "`$(date): ERROR - Script failed at line `$line_number with exit code `$exit_code" >> /var/log/bastion-setup.log
    exit `$exit_code
}

# Set error trap
trap 'handle_error `$LINENO' ERR

log_info "=========================================="
log_info "Samsung Cloud Platform v2 - Bastion Setup"
log_info "=========================================="
log_info "Timestamp: `$(date)"
log_info "User: `$(whoami)"
log_info "Working directory: `$(pwd)"
log_info "=========================================="

# Wait for network connectivity with timeout
log_info "Checking network connectivity..."
connectivity_timeout=300  # 5 minutes
connectivity_start=`$(date +%s)

until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do
    current_time=`$(date +%s)
    elapsed=`$((current_time - connectivity_start))

    if [ `$elapsed -gt `$connectivity_timeout ]; then
        log_error "Network connectivity timeout after 5 minutes"
        exit 1
    fi

    log_warning "Waiting for network connectivity... (`${elapsed}s elapsed)"
    sleep 10
done
log_success "Network connectivity confirmed"

# Wait for package manager to be ready
log_info "Waiting for package manager to be ready..."
for i in {1..30}; do
    if fuser /var/lib/rpm/.rpm.lock 2>/dev/null; then
        log_warning "Package manager is locked, waiting... (attempt `$i/30)"
        sleep 10
    else
        log_success "Package manager is ready"
        break
    fi
done

# Install git first (priority installation)
log_info "Installing git first..."
for i in {1..3}; do
    log_info "Git installation attempt `$i/3..."

    if dnf clean all && dnf makecache && dnf install -y git; then
        log_success "Git installed successfully"
        break
    else
        if [ `$i -eq 3 ]; then
            log_error "Git installation failed after 3 attempts"
            exit 1
        else
            log_warning "Git installation attempt `$i failed, retrying in 30 seconds..."
            sleep 30
        fi
    fi
done

# Verify git installation
if ! command -v git &> /dev/null; then
    log_error "Git command not found after installation"
    exit 1
fi

log_success "Git version: `$(git --version)"

# Change to home directory
cd /home/rocky

# Remove existing repository if present
if [ -d "advance_cloudnative" ]; then
    log_warning "Directory advance_cloudnative already exists, removing..."
    rm -rf advance_cloudnative
fi

# Clone the repository with retry logic
log_info "Cloning advance_cloudnative repository..."
for i in {1..3}; do
    log_info "Repository clone attempt `$i/3..."

    if git clone https://github.com/SCPv2/advance_cloudnative.git; then
        log_success "Repository cloned successfully"
        break
    else
        if [ `$i -eq 3 ]; then
            log_error "Repository clone failed after 3 attempts"
            exit 1
        else
            log_warning "Clone attempt `$i failed, retrying in 30 seconds..."
            sleep 30
        fi
    fi
done

# Verify repository structure
if [ ! -d "advance_cloudnative/container_app_deployment/k8s_app_deployment" ]; then
    log_error "Expected directory structure not found in cloned repository"
    exit 1
fi

# Set proper ownership
chown -R rocky:rocky advance_cloudnative

# Navigate to k8s deployment directory
cd advance_cloudnative/container_app_deployment/k8s_app_deployment

# Create setup-deployment.sh with actual values
log_info "Creating setup-deployment.sh with user values..."
cat > setup-deployment.sh << 'SETUP_SCRIPT_EOF'
$SetupScriptContent
SETUP_SCRIPT_EOF

# Make script executable and set ownership
chmod +x setup-deployment.sh
chown rocky:rocky setup-deployment.sh

# Verify setup script was created properly
if [ ! -f setup-deployment.sh ]; then
    log_error "Failed to create setup-deployment.sh"
    exit 1
fi

# Execute setup script as rocky user
log_info "Executing setup-deployment.sh..."
if sudo -u rocky ./setup-deployment.sh; then
    log_success "Setup script executed successfully"
else
    log_error "Setup script execution failed"
    exit 1
fi

# Final verification
log_info "Performing final verification..."
if [ -f k8s-manifests/configmap.yaml ] && [ -f k8s-manifests/master-config-configmap.yaml ]; then
    log_success "Configuration files verified successfully"
else
    log_error "Configuration files not found after setup"
    exit 1
fi

log_success "=========================================="
log_success "Bastion setup completed successfully!"
log_success "=========================================="
log_info "Setup Summary:"
log_info "  - Repository cloned to: /home/rocky/advance_cloudnative"
log_info "  - Configuration processed with user values"
log_info "  - All K8s manifests updated and ready for deployment"
log_info ""
log_info "Configuration files ready for deployment:"
log_info "  ✅ ConfigMap with domain configuration"
log_info "  ✅ Master config with Object Storage settings"
log_info "  ✅ External database service"
log_info "  ✅ Deployment manifests with container registry"
log_info ""
log_info "Next steps:"
log_info "1. SSH to this bastion server: ssh rocky@`$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
log_info "2. Navigate to: cd /home/rocky/advance_cloudnative/container_app_deployment/k8s_app_deployment"
log_info "3. Follow the manual deployment steps in README.md"
log_info "4. Start with: kubectl create namespace creative-energy"
log_info "=========================================="

# Final system update
log_info "Performing final system update..."
for i in {1..3}; do
    log_info "System update attempt `$i/3..."

    if dnf clean all && dnf makecache && dnf update -y; then
        log_success "System packages updated successfully"
        break
    else
        if [ `$i -eq 3 ]; then
            log_warning "System update failed after 3 attempts, but setup is complete"
        else
            log_warning "System update attempt `$i failed, retrying in 30 seconds..."
            sleep 30
        fi
    fi
done

# Log successful completion
echo "`$(date): Bastion userdata execution completed successfully" >> /var/log/bastion-setup.log
"@

    # Validate size (OpenStack 45KB limit)
    $OpenStackSizeLimit = 45000  # 45KB
    $sizeBytes = [System.Text.Encoding]::UTF8.GetByteCount($BastionUserData)

    Write-Host "Bastion UserData size: $sizeBytes bytes (limit: $OpenStackSizeLimit bytes)"

    if ($sizeBytes -gt $OpenStackSizeLimit) {
        Write-Error "Bastion UserData exceeds 45KB limit: $sizeBytes bytes"
        return $false
    }

    $sizePercentage = [math]::Round(($sizeBytes * 100 / $OpenStackSizeLimit), 1)
    Write-Success "Bastion UserData size validation passed: $sizeBytes bytes ($sizePercentage%)"

    # Save bastion userdata (UTF-8 without BOM with Unix line endings)
    $BastionUserdataFile = Join-Path $UserdataDir "userdata_bastion.sh"
    # Convert Windows line endings to Unix line endings
    $BastionUserDataUnix = $BastionUserData -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($BastionUserdataFile, $BastionUserDataUnix, [System.Text.UTF8Encoding]::new($false))

    Write-Success "✅ Bastion userdata generated: $BastionUserdataFile"
    Write-Host (Yellow "📊 Size: ") -NoNewline; Write-Host "$sizeBytes / $OpenStackSizeLimit bytes ($sizePercentage%)"
    return $true
}

# Main execution logic
function Main {
    Initialize-Environment

    if ($Reset) {
        Write-Info "🔄 RESET MODE: Restoring Kubernetes files to template defaults"
        Invoke-K8sTemplateReset
    }
    else {
        Write-Info "🔧 PROCESSING MODE: Applying user variables to Kubernetes files"

        # Load user variables
        $variables = Get-UserVariables

        # Process all template files
        Invoke-K8sTemplateProcessing $variables

        # Generate bastion userdata
        New-BastionUserData $variables

        # Show summary
        Show-ProcessingSummary $variables
    }

    Write-Host ""
    Green "🎉 Kubernetes Configuration Manager completed successfully!"
}

# Export debug mode for child processes
if ($Debug) {
    $env:DEBUG_MODE = "true"
    Write-Info "Debug mode enabled"
}

# Run main function
Main

# Exit with success
exit 0