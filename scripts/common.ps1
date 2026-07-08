$ErrorActionPreference = "Stop"

# ----------------------------
# runtime folders
# ----------------------------

$Script:Workspace = if ($env:WORKSPACE) {
    $env:WORKSPACE
}
else {
    "C:\Workspace"
}

$Script:Runtime = "C:\Runtime"

$Script:LogDir = Join-Path $Script:Runtime "logs"
$Script:ConfigDir = Join-Path $Script:Runtime "config"

$null = New-Item -ItemType Directory -Force -Path $Script:Workspace
$null = New-Item -ItemType Directory -Force -Path $Script:Runtime
$null = New-Item -ItemType Directory -Force -Path $Script:LogDir
$null = New-Item -ItemType Directory -Force -Path $Script:ConfigDir

# installer folders

$Script:InstallerFolder = Join-Path $Script:Workspace "Installers"
$Script:InstalledFolder = Join-Path $Script:Workspace "Installed"

$null = New-Item -ItemType Directory -Force -Path $Script:InstallerFolder
$null = New-Item -ItemType Directory -Force -Path $Script:InstalledFolder

# ----------------------------
# log
# ----------------------------

function Write-Log {

    param(
        [string]$Message,
        [string]$File = "general.log"
    )

    $log = Join-Path $Script:LogDir $File

    if (!(Test-Path (Split-Path $log))) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path (Split-Path $log) | Out-Null
    }

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content `
        -Path $log `
        -Value "[$time] $Message"

    Write-Host "[$time] $Message"
}

# ----------------------------
# retry helper
# ----------------------------

function Invoke-Retry {

    param(

        [scriptblock]$Action,

        [int]$RetryCount = 5,

        [int]$DelaySeconds = 10

    )

    for ($i = 1; $i -le $RetryCount; $i++) {

        try {

            Write-Log "Attempt $i"

            & $Action

            return

        }
        catch {

            Write-Log $_.Exception.Message

            if ($i -eq $RetryCount) {

                throw

            }

            Start-Sleep $DelaySeconds

        }

    }

}

# ----------------------------
# rclone
# ----------------------------

function Get-Rclone {

    $cmd = Get-Command rclone.exe -ErrorAction SilentlyContinue

    if ($cmd) {
        return $cmd.Source
    }

    $possible = @(

        "C:\Tools\rclone\rclone.exe",

        "$env:USERPROFILE\rclone\rclone.exe",

        "$Script:Runtime\rclone.exe"

    )

    foreach ($p in $possible) {

        if (Test-Path $p) {

            return $p

        }

    }

    throw "rclone.exe not found."

}

# ----------------------------
# paths
# ----------------------------

function Get-RcloneConfig {

    return Join-Path $Script:ConfigDir "rclone.conf"

}

function Get-WorkspaceRemote {

    return "oci:$($env:OCI_BUCKET)/workspace"

}

function Get-InstallerRemote {

    return "oci:$($env:OCI_BUCKET)/installers"

}

# ----------------------------
# sync upload
# ----------------------------

function Invoke-RcloneSync {

    param(

        [string]$Source,

        [string]$Destination

    )

    $rclone = Get-Rclone

    $config = Get-RcloneConfig

    & $rclone sync `
        $Source `
        $Destination `
        --config $config `
        --transfers 8 `
        --checkers 8 `
        --fast-list `
        --links `
        --create-empty-src-dirs `
        --copy-links `
        --retries 10 `
        --low-level-retries 10 `
        --log-level INFO

    if ($LASTEXITCODE -ne 0) {

        throw "rclone sync failed ($LASTEXITCODE)"

    }

}

# ----------------------------
# sync download
# ----------------------------

function Invoke-RcloneRestore {

    param(

        [string]$Remote,

        [            -Force `
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
