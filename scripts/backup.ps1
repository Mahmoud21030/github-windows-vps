$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

Write-Log "Starting workspace backup." "backup.log"

# ------------------------
# workspace backup
# ------------------------

Invoke-Retry {

    Write-Log "Uploading workspace..." "backup.log"

    Invoke-RcloneSync `
        -Source $Workspace `
        -Destination (Get-WorkspaceRemote)

}

# ------------------------
# installer backup
# ------------------------

Invoke-Retry {

    Write-Log "Uploading installers..." "backup.log"

    Invoke-RcloneSync `
        -Source $InstallerFolder `
        -Destination (Get-InstallerRemote)

}

# ------------------------
# upload state file
# ------------------------

$state = Join-Path $Workspace ".installed"

if (Test-Path $state) {

    Invoke-Retry {

        $rclone = Get-Rclone

        & $rclone copy `
            $state `
            (Get-WorkspaceRemote) `
            --config (Get-RcloneConfig) `
            --retries 10 `
            --low-level-retries 10 `
            --log-level INFO

        if ($LASTEXITCODE -ne 0) {

            throw "Failed to upload .installed"

        }

    }

}

# ------------------------
# summary
# ------------------------

$installerCount = (
    Get-ChildItem `
        $InstallerFolder `
        -File `
        -ErrorAction SilentlyContinue
).Count

Write-Log "Installer count: $installerCount" "backup.log"

Write-Log "Backup completed successfully." "backup.log"
