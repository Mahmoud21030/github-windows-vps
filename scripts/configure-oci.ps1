$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

$LogFile = "configure-oci.log"

Write-Log "Starting OCI configuration." $LogFile

function Require-Secret {

    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is missing."
    }

}

Write-Log "Checking required secrets." $LogFile

Require-Secret "OCI_USER_OCID" $env:OCI_USER_OCID
Require-Secret "OCI_TENANCY_OCID" $env:OCI_TENANCY_OCID
Require-Secret "OCI_COMPARTMENT_OCID" $env:OCI_COMPARTMENT_OCID
Require-Secret "OCI_FINGERPRINT" $env:OCI_FINGERPRINT
Require-Secret "OCI_PRIVATE_KEY" $env:OCI_PRIVATE_KEY
Require-Secret "OCI_NAMESPACE" $env:OCI_NAMESPACE
Require-Secret "OCI_REGION" $env:OCI_REGION
Require-Secret "OCI_BUCKET" $env:OCI_BUCKET

$configDir = Join-Path $Script:ConfigDir "oci"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $configDir | Out-Null

$OciKey = Join-Path $configDir "oci_private_key.pem"
$OciConfig = Join-Path $configDir "oci_config"
$RcloneConfig = Get-RcloneConfig

Write-Log "Writing OCI private key." $LogFile

$key = $env:OCI_PRIVATE_KEY
$key = $key.Replace("\r","")
$key = $key.Replace("\n","`n")

if (
    ($key -notmatch "BEGIN PRIVATE KEY") -and
    ($key -notmatch "BEGIN RSA PRIVATE KEY")
) {
    throw "Invalid private key."
}

Set-Content `
    -Path $OciKey `
    -Value $key `
    -Encoding ascii

Write-Log "Creating OCI config." $LogFile

@"
[DEFAULT]
user=$($env:OCI_USER_OCID)
tenancy=$($env:OCI_TENANCY_OCID)
fingerprint=$($env:OCI_FINGERPRINT)
region=$($env:OCI_REGION)
key_file=$OciKey
"@ | Set-Content `
    -Path $OciConfig `
    -Encoding ascii

Write-Log "Creating rclone config." $LogFile

@"
[oci]
type = oracleobjectstorage
provider = user_principal_auth

namespace = $($env:OCI_NAMESPACE)
region = $($env:OCI_REGION)

config_file = $OciConfig
config_profile = DEFAULT
compartment = $($env:OCI_COMPARTMENT_OCID)
"@ | Set-Content `
    -Path $RcloneConfig `
    -Encoding ascii

foreach ($file in @($OciKey,$OciConfig,$RcloneConfig)) {

    if (!(Test-Path $file)) {

        throw "Missing file: $file"

    }

}

$rclone = Get-Rclone

Write-Log "Testing rclone configuration." $LogFile

& $rclone listremotes `
    --config $RcloneConfig

if ($LASTEXITCODE -ne 0) {

    throw "Unable to load rclone configuration."

}

Write-Log "Testing Oracle bucket." $LogFile

& $rclone lsd `
    "oci:$($env:OCI_BUCKET)" `
    --config $RcloneConfig

if ($LASTEXITCODE -ne 0) {

    throw "Unable to access OCI bucket."

}

Write-Log "OCI configuration completed successfully." $LogFile
