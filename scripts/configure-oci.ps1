# configure-oci.ps1
# creates oracle object storage configuration

. "$PSScriptRoot\common.ps1"

Start-Log "configure-oci"


function Require-Value {

    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {

        throw "$Name is missing."
    }
}


Write-Log "Checking OCI secrets."


Require-Value "OCI_USER_OCID" $env:OCI_USER_OCID
Require-Value "OCI_TENANCY_OCID" $env:OCI_TENANCY_OCID
Require-Value "OCI_COMPARTMENT_OCID" $env:OCI_COMPARTMENT_OCID
Require-Value "OCI_FINGERPRINT" $env:OCI_FINGERPRINT
Require-Value "OCI_PRIVATE_KEY" $env:OCI_PRIVATE_KEY
Require-Value "OCI_NAMESPACE" $env:OCI_NAMESPACE
Require-Value "OCI_REGION" $env:OCI_REGION
Require-Value "OCI_BUCKET" $env:OCI_BUCKET



$keyFile = Join-Path $ConfigDir "oci_private_key.pem"

$ociConfig = Join-Path $ConfigDir "oci_config"



Write-Log "Writing OCI private key."


$privateKey = $env:OCI_PRIVATE_KEY -replace "`r`n", "`n"


Set-Content `
    -Path $keyFile `
    -Value $privateKey `
    -Encoding utf8



Write-Log "Creating OCI config."


@"
[DEFAULT]
user=$($env:OCI_USER_OCID)
tenancy=$($env:OCI_TENANCY_OCID)
fingerprint=$($env:OCI_FINGERPRINT)
region=$($env:OCI_REGION)
key_file=$keyFile
"@ | Set-Content `
        -Path $ociConfig `
        -Encoding ascii



Write-Log "Creating rclone configuration."


Write-Log "Creating OCI config."


@"
[DEFAULT]
user=$($env:OCI_USER_OCID)
tenancy=$($env:OCI_TENANCY_OCID)
fingerprint=$($env:OCI_FINGERPRINT)
region=$($env:OCI_REGION)
key_file=$keyFile
"@ | Set-Content `
    -Path $ociConfig `
    -Encoding ascii



Write-Log "Creating rclone configuration."


@"
[oci]
type = oracleobjectstorage
provider = user_principal_auth

namespace = $($env:OCI_NAMESPACE)
compartment = $($env:OCI_COMPARTMENT_OCID)
region = $($env:OCI_REGION)

config_file = $ociConfig
config_profile = DEFAULT
"@ | Set-Content `
    -Path $RcloneConfig `
    -Encoding ascii


Write-Log "Testing rclone configuration."


Invoke-Rclone @(
    "listremotes",
    "--config",
    $RcloneConfig
)



Write-Log "OCI configuration created successfully."


Write-Log "Remote:"
Write-Log "oci:$($env:OCI_BUCKET)/workspace"
