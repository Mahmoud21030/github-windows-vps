# ----------------------------
# compatibility
# ----------------------------

$Script:CurrentLogFile = "general.log"

$Script:OciDir = Join-Path $Script:ConfigDir "oci"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $Script:OciDir | Out-Null

$Script:OciKey = Join-Path $Script:OciDir "oci_private_key.pem"
$Script:OciConfig = Join-Path $Script:OciDir "oci_config"

Set-Variable `
    -Name Workspace `
    -Scope Global `
    -Value $Script:Workspace

Set-Variable `
    -Name Runtime `
    -Scope Global `
    -Value $Script:Runtime

Set-Variable `
    -Name InstallerFolder `
    -Scope Global `
    -Value $Script:InstallerFolder

Set-Variable `
    -Name InstalledFolder `
    -Scope Global `
    -Value $Script:InstalledFolder

Set-Variable `
    -Name OciKey `
    -Scope Global `
    -Value $Script:OciKey

Set-Variable `
    -Name OciConfig `
    -Scope Global `
    -Value $Script:OciConfig

Set-Variable `
    -Name RcloneConfig `
    -Scope Global `
    -Value (Get-RcloneConfig)

function Start-Log {

    param(
        [string]$Name
    )

    $Script:CurrentLogFile = "$Name.log"

    Write-Log "Starting $Name." $Script:CurrentLogFile

}

function Log {

    param(
        [string]$Message
    )

    Write-Log $Message $Script:CurrentLogFile

}

function Stop-Log {

    Write-Log "Finished." $Script:CurrentLogFile

}

function Invoke-Rclone {

    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    $rclone = Get-Rclone

    & $rclone @Arguments

    if ($LASTEXITCODE -ne 0) {

        throw "rclone exited with code $LASTEXITCODE"

    }

}
