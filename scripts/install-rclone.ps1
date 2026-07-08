# install-rclone.ps1
# installs latest rclone on github windows runner

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

$LogFile = "install-rclone.log"

Write-Log "Starting rclone installation." $LogFile

$installDir = "C:\Tools\rclone"
$rcloneExe = Join-Path $installDir "rclone.exe"

$tempDir = Join-Path $env:TEMP "rclone-download"
$zipFile = Join-Path $tempDir "rclone.zip"
$extractDir = Join-Path $tempDir "extract"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $installDir | Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $tempDir | Out-Null

function Install-Rclone {

    Write-Log "Checking existing installation." $LogFile

    if (Test-Path $rcloneExe) {

        try {

            $version = & $rcloneExe version

            if ($LASTEXITCODE -eq 0) {

                Write-Log $version[0] $LogFile

                $env:PATH += ";$installDir"

                if ($env:GITHUB_PATH) {

                    "$installDir" | Out-File `
                        -FilePath $env:GITHUB_PATH `
                        -Encoding utf8 `
                        -Append

                }

                return

            }

        }
        catch {

            Write-Log "Existing rclone is invalid." $LogFile

        }

    }

    Write-Log "Downloading latest release." $LogFile

    Invoke-Retry {

        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/rclone/rclone/releases/latest" `
            -Headers @{
                "User-Agent" = "github-actions"
            }

        $asset = $release.assets |
            Where-Object {
                $_.name -match "windows-amd64.zip$"
            } |
            Select-Object -First 1

        if ($null -eq $asset) {

            throw "Unable to locate Windows AMD64 release."

        }

        Write-Log "Version: $($release.tag_name)" $LogFile

        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -OutFile $zipFile `
            -UseBasicParsing

    }

    if (Test-Path $extractDir) {

        Remove-Item `
            -Path $extractDir `
            -Force `
            -Recurse

    }

    Write-Log "Extracting archive." $LogFile

    Expand-Archive `
        -Path $zipFile `
        -DestinationPath $extractDir `
        -Force

    $binary = Get-ChildItem `
        -Path $extractDir `
        -Filter "rclone.exe" `
        -Recurse |
        Select-Object -First 1

    if ($null -eq $binary) {

        throw "rclone.exe not found after extraction."

    }

    Copy-Item `
        -Path $binary.FullName `
        -Destination $rcloneExe `
        -Force

    $env:PATH += ";$installDir"

    if ($env:GITHUB_PATH) {

        "$installDir" | Out-File `
            -FilePath $env:GITHUB_PATH `
            -Encoding utf8 `
            -Append

    }

    $version = & $rcloneExe version

    if ($LASTEXITCODE -ne 0) {

        throw "rclone verification failed."

    }

    Write-Log $version[0] $LogFile

    Write-Log "Installation completed successfully." $LogFile

}

Install-Rclone

Write-Log "Cleaning temporary files." $LogFile

Remove-Item `
    -Path $tempDir `
    -Force `
    -Recurse `
    -ErrorAction SilentlyContinue

Write-Log "install-rclone.ps1 completed." $LogFile
