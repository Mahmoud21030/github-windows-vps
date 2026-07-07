# install-rclone.ps1
# downloads and installs the latest stable rclone for windows

$ErrorActionPreference = "Stop"

$workspace = "C:\Workspace"
$logDir = Join-Path $workspace "logs"
$tempDir = Join-Path $env:TEMP "rclone_install"
$zipFile = Join-Path $tempDir "rclone.zip"
$extractDir = Join-Path $tempDir "extract"
$installDir = "C:\Tools\rclone"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$logFile = Join-Path $logDir "install-rclone.log"

function Write-Log {
    param([string]$msg)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] $msg"

    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Invoke-Retry {
    param(
        [scriptblock]$Script,
        [int]$Retries = 5,
        [int]$DelaySeconds = 10
    )

    for ($i = 1; $i -le $Retries; $i++) {

        try {
            & $Script
            return
        }
        catch {

            Write-Log "Attempt $i failed."

            if ($i -eq $Retries) {
                throw
            }

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

Write-Log "Starting rclone installation."

$rcloneExe = Join-Path $installDir "rclone.exe"

if (Test-Path $rcloneExe) {

    try {

        $version = & $rcloneExe version

        Write-Log "Existing rclone detected."
        Write-Log $version[0]

        $env:Path += ";$installDir"

        return
    }
    catch {

        Write-Log "Existing installation is invalid. Reinstalling."
    }
}

$releaseApi = "https://api.github.com/repos/rclone/rclone/releases/latest"

Write-Log "Fetching latest release."

Invoke-Retry {

    $release = Invoke-RestMethod `
        -Uri $releaseApi `
        -UseBasicParsing

    $asset = $release.assets |
        Where-Object {
            $_.name -match "windows-amd64.zip$"
        } |
        Select-Object -First 1

    if (-not $asset) {
        throw "Unable to locate Windows release asset."
    }

    Write-Log "Latest version: $($release.tag_name)"
    Write-Log "Downloading $($asset.name)"

    Invoke-WebRequest `
        -Uri $asset.browser_download_url `
        -OutFile $zipFile `
        -UseBasicParsing
}

Write-Log "Extracting archive."

if (Test-Path $extractDir) {
    Remove-Item $extractDir -Recurse -Force
}

Expand-Archive `
    -Path $zipFile `
    -DestinationPath $extractDir `
    -Force

$exe = Get-ChildItem `
    -Path $extractDir `
    -Filter rclone.exe `
    -Recurse |
    Select-Object -First 1

if (-not $exe) {
    throw "rclone.exe not found after extraction."
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $installDir | Out-Null

Copy-Item `
    -Path $exe.FullName `
    -Destination $rcloneExe `
    -Force

$env:Path += ";$installDir"

Write-Log "Verifying installation."

Invoke-Retry {

    $v = & $rcloneExe version

    if ($LASTEXITCODE -ne 0) {
        throw "Version check failed."
    }

    Write-Log $v[0]
}

Write-Log "Cleaning temporary files."

Remove-Item $tempDir -Force -Recurse -ErrorAction SilentlyContinue

Write-Log "rclone installation completed successfully."
