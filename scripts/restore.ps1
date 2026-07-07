# restore.ps1
# restores workspace from oracle object storage

. "$PSScriptRoot\common.ps1"

Start-Log "restore"


$remote = Get-Remote


Write-Log "Starting workspace restore."



function Test-RemoteExists {

    try {

        $result = & $RcloneExe `
            lsf `
            $remote `
            --config $RcloneConfig `
            --max-depth 1

        if ($LASTEXITCODE -ne 0) {

            throw "Remote check failed."
        }


        return $true

    }
    catch {

        return $false
    }
}



$hasBackup = Test-RemoteExists



if (-not $hasBackup) {

    Write-Log "No previous workspace backup found."

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $Workspace | Out-Null


    Write-Log "Created empty workspace."

    exit 0
}



Write-Log "Existing backup detected."



Invoke-Retry {

    Write-Log "Downloading workspace."


    Invoke-Rclone @(
        "sync",
        $remote,
        $Workspace,
        "--config",
        $RcloneConfig,
        "--create-empty-src-dirs",
        "--fast-list",
        "--transfers",
        "8",
        "--checkers",
        "8",
        "--retries",
        "5",
        "--retries-sleep",
        "10s",
        "--low-level-retries",
        "10",
        "--stats",
        "30s"
    )

}



Write-Log "Checking restored files."



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
