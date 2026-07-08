# restore.ps1

. "$PSScriptRoot\common.ps1"

Start-Log "restore"

$remote = Get-Remote

Write-Log "Checking remote workspace."

# first determine whether the remote exists
try {

    Invoke-Rclone @(
        "lsf",
        $remote,
        "--config",
        $RcloneConfig,
        "--max-depth",
        "1"
    )

    $remoteExists = $true

}
catch {

    $remoteExists = $false

}

if (-not $remoteExists) {

    Write-Log "No previous backup found."

    if (!(Test-Path $Workspace)) {

        New-Item `
            -ItemType Directory `
            -Force `
            -Path $Workspace | Out-Null

    }

    Write-Log "Created empty workspace."

    exit 0

}

Write-Log "Restoring workspace."

Invoke-Retry {

    Invoke-Rclone @(
        "sync",
        $remote,
        $Workspace,
        "--config",
        $RcloneConfig,
        "--fast-list",
        "--transfers",
        "8",
        "--checkers",
        "8",
        "--create-empty-src-dirs",
        "--retries",
        "5",
        "--low-level-retries",
        "10",
        "--stats",
        "30s"
    )

}

Write-Log "Verifying restored files."

Invoke-Retry {

    & $RcloneExe `
        check `
        $remote `
        $Workspace `
        --config $RcloneConfig `
        --one-way

    if ($LASTEXITCODE -gt 1) {

        throw "Restore verification failed."

    }

}

$stats = Get-WorkspaceStats

Write-Log "Restore completed."

Write-Log "Files: $($stats.Files)"
Write-Log "Directories: $($stats.Directories)"
Write-Log "Size MB: $($stats.SizeMB)"
