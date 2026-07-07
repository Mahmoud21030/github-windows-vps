# configure-oci.ps1
# creates oracle cloud api config and rclone config

$ErrorActionPreference = "Stop"

$workspace = "C:\Workspace"

$configDir = Join-Path $workspace "config"
$logDir    = Join-Path $workspace "logs"

New-Item -ItemType Directory -Force -Path $configDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$logFile = Join-Path $logDir "configure-oci.log"

function Write-Log {
    param([string]$msg)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] $msg"

    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Require-Secret {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "GitHub Secret '$Name' is missing."
    }
}

Write-Log "Checking required secrets."

Require-Secret "OCI_USER_OCID"        $env:OCI_USER_OCID
Require-Secret "OCI_TENANCY_OCID"     $env:OCI_TENANCY_OCID
Require-Secret "OCI_FINGERPRINT"      $env:OCI_FINGERPRINT
Require-Secret "OCI_PRIVATE_KEY"      $env:OCI_PRIVATE_KEY
Require-Secret "OCI_NAMESPACE"        $env:OCI_NAMESPACE
Require-Secret "OCI_REGION"           $env:OCI_REGION
Require-Secret "OCI_BUCKET"           $env:OCI_BUCKET
Require-Secret "OCI_COMPARTMENT_OCID" $env:OCI_COMPARTMENT_OCID

$keyFile = Join-Path $configDir "oci_api_key.pem"

Write-Log "Writing private key."

$key = $env:OCI_PRIVATE_KEY -replace "`r",""

Set-Content `
    -Path $keyFile `
    -Value $key `
    -Encoding ascii

$configFile = Join-Path $configDir "oci_config"

Write-Log "Creating OCI config."

@"
[DEFAULT]
user=$($env:OCI_USER_OCID)
fingerprint=$($env:OCI_FINGERPRINT)
tenancy=$($env:OCI_TENANCY_OCID)
region=$($env:OCI_REGION)
key_file=$keyFile
"@ | Set-Content `
        -Encoding ascii `
        -Path $configFile

$rcloneConfig = Join-Path $configDir "rclone.conf"

Write-Log "Creating rclone configuration."

@"
[oci]
type = oracleobjectstorage
provider = oracle
namespace = $($env:OCI_NAMESPACE)
region = $($env:OCI_REGION)
compartment = $($env:OCI_COMPARTMENT_OCID)

env_auth = false

user = $($env:OCI_USER_OCID)
tenancy = $($env:OCI_TENANCY_OCID)
fingerprint = $($env:OCI_FINGERPRINT)
key_file = $keyFile
"@ | Set-Content `
        -Encoding ascii `
        -Path $rcloneConfig

$env:RCLONE_CONFIG = $rcloneConfig

Write-Log "Testing rclone configuration."

$rclone = Get-Command rclone.exe -ErrorAction Stop

& $rclone.Source `
    listremotes `
    --config $rcloneConfig | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Unable to read rclone configuration."
}

Write-Log "Configuration verified."

Write-Log ""
Write-Log "Remote name : oci"
Write-Log "Bucket      : $($env:OCI_BUCKET)"
Write-Log "Region      : $($env:OCI_REGION)"
Write-Log "Namespace   : $($env:OCI_NAMESPACE)"
Write-Log ""

Write-Log "Oracle Cloud configuration completed successfully."
