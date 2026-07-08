# backup.ps1
# uploads changed workspace files to oracle object storage

. "$PSScriptRoot\common.ps1"

Start-Log "backup"


$remote = Get-Remote


if (!(Test-Path $Workspace)) {

    throw "Workspace directory does not exist."
}



Write-Log "Starting workspace backup."



Invoke-Retry {

    Write-Log "Running incremental sync."


    Invoke-Rclone @(
        "sync",
        $Workspace,
        $remote,
        "--config",
        $RcloneConfig,
        "--create-empty-src-dirs",
        "--fast-list",
        "--transfers",
        "8",
        "--checkers",
        "8",
        "--track-renames",
        "--metadata",
        "--copy-links",
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



Write-Log "Sync completed."
. "$PSScriptRoot\common.ps1"

Start-Log "backup"


$remote = Get-Remote


Write-Log "Starting backup."


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
