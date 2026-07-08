# configure-oci.ps1

. "$PSScriptRoot\common.ps1"

Start-Log "configure-oci"

function Require-Secret {

    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is missing."
    }

}

Write-Log "Checking required secrets."

Require-Secret "OCI_USER_OCID" $env:OCI_USER_OCID
Require-Secret "OCI_TENANCY_OCID" $env:OCI_TENANCY_OCID
Require-Secret "OCI_COMPARTMENT_OCID" $env:OCI_COMPARTMENT_OCID
Require-Secret "OCI_FINGERPRINT" $env:OCI_FINGERPRINT
Require-Secret "OCI_PRIVATE_KEY" $env:OCI_PRIVATE_KEY
Require-Secret "OCI_NAMESPACE" $env:OCI_NAMESPACE
Require-Secret "OCI_REGION" $env:OCI_REGION
Require-Secret "OCI_BUCKET" $env:OCI_BUCKET

Write-Log "Writing OCI private key."

$key = $env:OCI_PRIVATE_KEY

$key = $key.Replace("\n","`n")
$key = $key.Replace("`r`n","`n")

if (
    ($key -notmatch "BEGIN PRIVATE KEY") -and
    ($key -notmatch "BEGIN RSA PRIVATE KEY")
) {
    throw "Invalid private key header."
}

if (
    ($key -notmatch "END PRIVATE KEY") -and
    ($key -notmatch "END RSA PRIVATE KEY")
) {
    throw "Invalid private key footer."
}

Set-Content `
    -Path $OciKey `
    -Value $key `
    -Encoding ascii `
    -NoNewline

Write-Log "Creating OCI configuration."

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

Write-Log "Creating rclone configuration."

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

Write-Log "Checking generated files."

foreach ($file in @($OciKey,$OciConfig,$RcloneConfig)) {

    if (!(Test-Path $file)) {

        throw "Missing file: $file"

    }

}

Write-Log "Testing rclone configuration."

Invoke-Rclone @(
    "listremotes",
    "--config",
    $RcloneConfig
)

Write-Log "Testing bucket access."

Invoke-Rclone @(
    "lsd",
    "oci:$($env:OCI_BUCKET)",
    "--config",
    $RcloneConfig
)

Write-Log "OCI configuration completed successfully."
