# common.ps1

$ErrorActionPreference = "Stop"

# ---------- paths ----------

$Global:Workspace = "C:\Workspace"

$Global:RuntimeDir = "C:\Runtime"

$Global:ConfigDir = Join-Path $RuntimeDir "config"

$Global:LogDir = Join-Path $RuntimeDir "logs"

$Global:RcloneExe = "C:\Tools\rclone\rclone.exe"

$Global:RcloneConfig = Join-Path $ConfigDir "rclone.conf"

$Global:OciConfig = Join-Path $ConfigDir "oci_config"

$Global:OciKey = Join-Path $ConfigDir "oci_private_key.pem"


foreach ($dir in @(
    $Workspace,
    $RuntimeDir,
    $ConfigDir,
    $LogDir,
    "C:\Tools",
    "C:\Tools\rclone"
)) {

    if (!(Test-Path $dir)) {

        New-Item `
            -ItemType Directory `
            -Force `
            -Path $dir | Out-Null

    }

}



# ---------- logging ----------

function Start-Log {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $script:LogFile = Join-Path $LogDir "$Name.log"

    if (!(Test-Path $script:LogFile)) {

        New-Item `
            -ItemType File `
            -Force `
            -Path $script:LogFile | Out-Null

    }

}



function Write-Log {

    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $line = "[$time] $Message"

    Write-Host $line

    $folder = Split-Path $script:LogFile -Parent

    if (!(Test-Path $folder)) {

        New-Item `
            -ItemType Directory `
            -Force `
            -Path $folder | Out-Null

    }

    Add-Content `
        -Path $script:LogFile `
        -Value $line

}



# ---------- retry ----------

function Invoke-Retry {

    param(

        [Parameter(Mandatory)]
        [scriptblock]$Script,

        [int]$Retries = 5,

        [int]$DelaySeconds = 10

    )

    $last = $null

    for ($i = 1; $i -le $Retries; $i++) {

        try {

            Write-Log "Attempt $i"

            & $Script

            return

        }
        catch {

            $last = $_

            Write-Log $_.Exception.Message

            if ($i -lt $Retries) {

                Start-Sleep -Seconds $DelaySeconds

            }

        }

    }

    throw $last

}



# ---------- rclone ----------

function Get-Rclone {

    if (!(Test-Path $RcloneExe)) {

        throw "rclone.exe not found at $RcloneExe"

    }

    return $RcloneExe

}



function Invoke-Rclone {

    param(

        [Parameter(Mandatory)]
        [string[]]$Arguments

    )

    $exe = Get-Rclone

    & $exe @Arguments

    if ($LASTEXITCODE -ne 0) {

        throw "rclone exited with code $LASTEXITCODE"

    }

}



# ---------- remote ----------

function Get-Remote {

    if ([string]::IsNullOrWhiteSpace($env:OCI_BUCKET)) {

        throw "OCI_BUCKET is not set."

    }

    return "oci:$($env:OCI_BUCKET)/workspace"

}



# ---------- validation ----------

function Test-RcloneConfig {

    if (!(Test-Path $RcloneConfig)) {

        throw "Missing rclone configuration."

    }

    Invoke-Rclone @(
        "listremotes",
        "--config",
        $RcloneConfig
    )

}



# ---------- workspace stats ----------

function Get-WorkspaceStats {

    if (!(Test-Path $Workspace)) {

        return [PSCustomObject]@{
            Files = 0
            Directories = 0
            SizeMB = 0
        }

    }

    $files = Get-ChildItem `
        $Workspace `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue

    $dirs = Get-ChildItem `
        $Workspace `
        -Directory `
        -Recurse `
        -ErrorAction SilentlyContinue

    $size = ($files | Measure-Object Length -Sum).Sum

    if ($null -eq $size) {

        $size = 0

    }

    return [PSCustomObject]@{

        Files = $files.Count

        Directories = $dirs.Count

        SizeMB = [Math]::Round($size / 1MB, 2)

    }

}
