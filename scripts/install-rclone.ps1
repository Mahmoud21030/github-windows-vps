# install-rclone.ps1
# installs rclone for windows github runners

. "$PSScriptRoot\common.ps1"

Start-Log "install-rclone"

$installDir = "C:\Tools\rclone"
$rcloneExe = Join-Path $installDir "rclone.exe"

$tempDir = Join-Path $env:TEMP "rclone-download"

$zipFile = Join-Path $tempDir "rclone.zip"

New-Item `
    -ItemType Directory `
    -Force `
    -Path $installDir | Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $tempDir | Out-Null


function Install-Rclone {

    Write-Log "Checking existing rclone."

    if (Test-Path $rcloneExe) {

        try {

            $version = & $rcloneExe version

            Write-Log "Existing installation found."
            Write-Log $version[0]

            return
        }
        catch {

            Write-Log "Existing rclone is invalid."
        }
    }


    Write-Log "Downloading latest rclone."

    Invoke-Retry {

        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/rclone/rclone/releases/latest" `
            -Headers @{
                "User-Agent"="github-actions"
            }


        $asset = $release.assets |
            Where-Object {

                $_.name -match "windows-amd64.zip$"

            } |
            Select-Object -First 1


        if ($null -eq $asset) {

            throw "Windows AMD64 rclone package not found."
        }


        Write-Log "Version: $($release.tag_name)"

        Write-Log "Downloading:"
        Write-Log $asset.name


        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -OutFile $zipFile `
            -UseBasicParsing

    }



    Write-Log "Extracting archive."


    $extractDir = Join-Path $tempDir "extract"


    if (Test-Path $extractDir) {

        Remove-Item `
            -Path $extractDir `
            -Recurse `
            -Force
    }


    Expand-Archive `
        -Path $zipFile `
        -DestinationPath $extractDir `
        -Force



    Write-Log "Searching for rclone.exe."


    $binary = Get-ChildItem `
        -Path $extractDir `
        -Filter "rclone.exe" `
        -Recurse |
        Select-Object -First 1


    if ($null -eq $binary) {

        throw "rclone.exe missing after extraction."
    }



    Copy-Item `
        -Path $binary.FullName `
        -Destination $rcloneExe `
        -Force



    Write-Log "Testing installation."


    & $rcloneExe version


    if ($LASTEXITCODE -ne 0) {

        throw "rclone verification failed."
    }


    Write-Log "rclone installed successfully."

}



Install-Rclone



Write-Log "Cleaning temporary files."


Remove-Item `
    -Path $tempDir `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue


Write-Log "Installation finished."
