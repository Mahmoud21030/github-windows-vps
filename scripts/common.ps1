# common.ps1
# shared functions for all scripts

$ErrorActionPreference = "Stop"

# ----------------------------
# paths
# ----------------------------

$Global:Workspace = "C:\Workspace"

$Global:ConfigDir = Join-Path $Workspace "config"

$Global:LogDir = Join-Path $Workspace "logs"

$Global:RcloneExe = "C:\Tools\rclone\rclone.exe"

$Global:RcloneConfig = Join-Path $ConfigDir "rclone.conf"

New-Item -ItemType Directory -Force -Path $Workspace | Out-Null
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# ----------------------------
# logger
# ----------------------------

function Start-Log {

    param(
        [string]$Name
    )

    $script:LogFile = Join-Path $LogDir "$Name.log"

    if (!(Test-Path $script:LogFile)) {

        New-Item `
            -ItemType File `
            -Path $script:LogFile `
            -Force | Out-Null
    }
}

function Write-Log {

    param(
        [string]$Message
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $line = "[$time] $Message"

    Write-Host $line

    if ($script:LogFile) {

        Add-Content `
            -Path $script:LogFile `
            -Value $line
    }
}

# ----------------------------
# retry helper
# ----------------------------

function Invoke-Retry {

    param(

        [scriptblock]$Script,

        [int]$Retries = 5,

        [int]$DelaySeconds = 10
    )

    $lastError = $null

    for ($i = 1; $i -le $Retries; $i++) {

        try {

            Write-Log "Attempt $i"

            & $Script

            return

        }
        catch {

            $lastError = $_

            Write-Log $_.Exception.Message

            if ($i -lt $Retries) {

                Start-Sleep -Seconds $DelaySeconds
            }

        }

    }

    throw $lastError
}

# ----------------------------
# verify rclone
# ----------------------------

function Get-Rclone {

    if (!(Test-Path $RcloneExe)) {

        throw "rclone.exe not found: $RcloneExe"
    }

    return $RcloneExe
}

# ----------------------------
# run rclone
# ----------------------------

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

# ----------------------------
# bucket path
# ----------------------------

function Get-Remote {

    if ([string]::IsNullOrWhiteSpace($env:OCI_BUCKET)) {

        throw "OCI_BUCKET is not set."
    }

    return "oci:$($env:OCI_BUCKET)/workspace"
}

# ----------------------------
# validate config
# ----------------------------

function Test-RcloneConfig {

    if (!(Test-Path $RcloneConfig)) {

        throw "Missing rclone.conf"
    }

    Invoke-Rclone @(
        "listremotes",
        "--config",
        $RcloneConfig
    )
}

# ----------------------------
# workspace statistics
# ----------------------------

function Get-WorkspaceStats {

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

    [PSCustomObject]@{

        Files = $files.Count

        Directories = $dirs.Count

        SizeMB = [math]::Round(
            (($files | Measure-Object Length -Sum).Sum / 1MB),
            2
        )

    }

}
