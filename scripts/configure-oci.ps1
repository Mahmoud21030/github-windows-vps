# configure-oci.ps1
# creates oracle object storage authentication files

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



Write-Log "Checking OCI secrets."


Require-Secret "OCI_USER_OCID" $env:OCI_USER_OCID
Require-Secret "OCI_TENANCY_OCID" $env:OCI_TENANCY_OCID
Require-Secret "OCI_COMPARTMENT_OCID" $env:OCI_COMPARTMENT_OCID
Require-Secret "OCI_FINGERPRINT" $env:OCI_FINGERPRINT
Require-Secret "OCI_PRIVATE_KEY" $env:OCI_PRIVATE_KEY
Require-Secret "OCI_NAMESPACE" $env:OCI_NAMESPACE
Require-Secret "OCI_REGION" $env:OCI_REGION
Require-Secret "OCI_BUCKET" $env:OCI_BUCKET



$keyFile = Join-Path $ConfigDir "oci_private_key.pem"

$ociConfigFile = Join-Path $ConfigDir "oci_config"



Write-Log "Preparing private key."



$privateKey = $env:OCI_PRIVATE_KEY


# github secrets may store newlines as literal \n
$privateKey = $privateKey.Replace("\n", "`n")


# normalize windows line endings
$privateKey = $privateKey.Replace("`r`n", "`n")



if (
    ($privateKey -notmatch "BEGIN PRIVATE KEY") -and
    ($privateKey -notmatch "BEGIN RSA PRIVATE KEY")
) {

    throw "Private key header not found."
}



if (
    ($privateKey -notmatch "END PRIVATE KEY") -and
    ($privateKey -notmatch "END RSA PRIVATE KEY")
) {

    throw "Private key footer not found."
}



Set-Content `
    -Path $keyFile `
    -Value $privateKey `
    -Encoding ascii `
    -NoNewline



Write-Log "Private key created."



Write-Log "Creating OCI config."



@"
[DEFAULT]
user=$($env:OCI_USER_OCID)
tenancy=$($env:OCI_TENANCY_OCID)
fingerprint=$($env:OCI_FINGERPRINT)
region=$($env:OCI_REGION)
key_file=$keyFile
"@ |
Set-Content `
    -Path $ociConfigFile `
    -Encoding ascii



Write-Log "Creating rclone configuration."



@"
[oci]
type = oracleobjectstorage
provider = user_principal_auth

namespace = $($env:OCI_NAMESPACE)
region = $($env:OCI_REGION)
compartment = $($env:OCI_COMPARTMENT_OCID)

config_file = $ociConfigFile
config_profile = DEFAULT
"@ |
Set-Content `
    -Path $RcloneConfig `
    -Encoding ascii



Write-Log "Checking generated files."


if (!(Test-Path $keyFile)) {

    throw "Private key file was not created."
}


if (!(Test-Path $ociConfigFile)) {

    throw "OCI config was not created."
}


if (!(Test-Path $RcloneConfig)) {

    throw "rclone config was not created."
}



Write-Log "Testing rclone OCI remote."



Invoke-Retry {

    Invoke-Rclone @(
        "listremotes",
        "--config",
        $RcloneConfig
    )

}



Write-Log "OCI configuration completed."

Write-Log "Remote: oci:$($env:OCI_BUCKET)/workspace"
