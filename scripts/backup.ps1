# backup.ps1

. "$PSScriptRoot\common.ps1"

Start-Log "backup"

$remote = Get-Remote

Write-Log "Starting workspace backup."

if (!(Test-Path $Workspace)) {

    throw "Workspace directory does not exist."

}


Invoke-Retry {

    Write-Log "Running incremental sync."


    Invoke-Rclone @(
        "sync",
        $Workspace,
        $remote,
        "--config",
        $RcloneConfig,

        # keep runtime data and secrets out of object storage
        "--exclude",
        "config/**",

        "--exclude",
        "logs/**",

        "--exclude",
        "*.pem",

        "--exclude",
        "*.key",

        "--fast-list",

        "--transfers",
        "8",

        "--checkers",
        "8",

        "--track-renames",

        "--create-empty-src-dirs",

        "--retries",
        "5",

        "--low-level-retries",
        "10",

        "--retries-sleep",
        "10s",

        "--stats",
        "30s"
    )

}


Write-Log "Backup sync completed."


Write-Log "Checking remote upload."


Invoke-Retry {

    & $RcloneExe `
        check `
        $Workspace `
        $remote `
        --config $RcloneConfig `
        --one-way


    if ($LASTEXITCODE -gt 1) {

        throw "Backup verification failed."

    }

}


$stats = Get-WorkspaceStats


Write-Log "Backup completed successfully."

Write-Log "Files: $($stats.Files)"

Write-Log "Directories: $($stats.Directories)"

Write-Log "Size MB: $($stats.SizeMB)"
Invoke-Retry {

    Invoke-Rclone @(

        "sync",

        $Workspace,

        $remote,

        "--config",

        $RcloneConfig,

        "--exclude",

        "config/**",

        "--exclude",

        "logs/**",

        "--fast-list",

        "--transfers",

        "8",

        "--checkers",

        "8",

        "--retries",

        "5",

        "--retries-sleep",

        "10s"

    )

}


Write-Log "Backup complete."



Write-Log "Verifying remote files."



Invoke-Retry {

    & $RcloneExe `
        check `
        $Workspace `
        $remote `
        --config $RcloneConfig `
        --one-way


    if ($LASTEXITCODE -gt 1) {

        throw "Backup verification failed."
    }

}



$stats = Get-WorkspaceStats


Write-Log "Backup completed successfully."

Write-Log "Files: $($stats.Files)"

Write-Log "Directories: $($stats.Directories)"

Write-Log "Size MB: $($stats.SizeMB)"
