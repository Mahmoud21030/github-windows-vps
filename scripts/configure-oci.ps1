$ErrorActionPreference = 'Stop'

Write-Host "[Configure-OCI] Starting OCI configuration script..."

# Ensure all required environment variables are present
$requiredEnvVars = @(
    'OCI_USER_OCID',
    'OCI_TENANCY_OCID',
    'OCI_COMPARTMENT_OCID',
    'OCI_FINGERPRINT',
    'OCI_PRIVATE_KEY',
    'OCI_NAMESPACE',
    'OCI_REGION',
    'OCI_BUCKET'
)

foreach ($var in $requiredEnvVars) {
    if (-not (Get-Item Env:$var -ErrorAction SilentlyContinue)) {
        Write-Error "[Configure-OCI] Missing required environment variable: $var"
        exit 1
    }
}

# Create .oci directory for OCI config file
$ociConfigDir = "$env:USERPROFILE\.oci"
if (-not (Test-Path $ociConfigDir)) {
    Write-Host "[Configure-OCI] Creating OCI config directory: $ociConfigDir"
    New-Item -Path $ociConfigDir -ItemType Directory | Out-Null
}

# Create OCI config file
$ociConfigFile = "$ociConfigDir\config"
Write-Host "[Configure-OCI] Generating OCI config file: $ociConfigFile"
$ociConfigContent = @"
[DEFAULT]
user=$env:OCI_USER_OCID
tenancy=$env:OCI_TENANCY_OCID
region=$env:OCI_REGION
fingerprint=$env:OCI_FINGERPRINT
key_file=$ociConfigDir\oci_api_key.pem
compartment_ocid=$env:OCI_COMPARTMENT_OCID
"@
$ociConfigContent | Set-Content -Path $ociConfigFile

# Write private key to file
$privateKeyFile = "$ociConfigDir\oci_api_key.pem"
Write-Host "[Configure-OCI] Writing private key to: $privateKeyFile"
$env:OCI_PRIVATE_KEY | Set-Content -Path $privateKeyFile

# Generate rclone.conf from template
$rcloneConfigPath = "$env:USERPROFILE\.config\rclone"
if (-not (Test-Path $rcloneConfigPath)) {
    Write-Host "[Configure-OCI] Creating rclone config directory: $rcloneConfigPath"
    New-Item -Path $rcloneConfigPath -ItemType Directory | Out-Null
}

$rcloneConfigFile = "$rcloneConfigPath\rclone.conf"
Write-Host "[Configure-OCI] Generating rclone.conf file: $rcloneConfigFile"

# Load rclone.conf.template content
$rcloneTemplateContent = Get-Content -Path "config\rclone.conf.template" -Raw

# Replace placeholders with environment variables
$rcloneConfigContent = $rcloneTemplateContent `
    -replace "\{\{OCI_NAMESPACE\}\}", $env:OCI_NAMESPACE `
    -replace "\{\{OCI_REGION\}\}", $env:OCI_REGION `
    -replace "\{\{OCI_COMPARTMENT_OCID\}\}", $env:OCI_COMPARTMENT_OCID `
    -replace "\{\{OCI_USER_OCID\}\}", $env:OCI_USER_OCID `
    -replace "\{\{OCI_TENANCY_OCID\}\}", $env:OCI_TENANCY_OCID `
    -replace "\{\{OCI_FINGERPRINT\}\}", $env:OCI_FINGERPRINT

$rcloneConfigContent | Set-Content -Path $rcloneConfigFile

Write-Host "[Configure-OCI] OCI configuration script finished."
