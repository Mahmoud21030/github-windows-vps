#"$PSScriptRoot\common.ps1"

Start-Log "configure-oci"


function Check($name,$value){

    if ([string]::IsNullOrWhiteSpace($value)){

        throw "$name missing"
    }
}


Check "OCI_USER_OCID" $env:OCI_USER_OCID
Check "OCI_TENANCY_OCID" $env:OCI_TENANCY_OCID
Check "OCI_FINGERPRINT" $env:OCI_FINGERPRINT
Check "OCI_PRIVATE_KEY" $env:OCI_PRIVATE_KEY
Check "OCI_NAMESPACE" $env:OCI_NAMESPACE
Check "OCI_REGION" $env:OCI_REGION
Check "OCI_BUCKET" $env:OCI_BUCKET



$keyFile = Join-Path $RuntimeDir "oci_private_key.pem"

$ociConfigFile = Join-Path $RuntimeDir "oci_config"



$key = $env:OCI_PRIVATE_KEY

$key = $key.Replace("\n","`n")

$key = $key.Replace("`r`n","`n")



Set-Content `
    -Path $keyFile `
    -Value $key `
    -Encoding ascii `
    -NoNewline



@"
[DEFAULT]
user=$($env:OCI_USER_OCID)
tenancy=$($env:OCI_TENANCY_OCID)
fingerprint=$($env:OCI_FINGERPRINT)
region=$($env:OCI_REGION)
key_file=$keyFile
"@ |
Set-Content `
    -Path $ociConfigFile



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
    -Path $RcloneConfig



Write-Log "OCI configured."
