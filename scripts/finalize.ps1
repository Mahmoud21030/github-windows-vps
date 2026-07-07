# finalize.ps1
# performs final verified backup before runner shutdown

. "$PSScriptRoot\common.ps1"

Start-Log "finalize"


$backupScript = Join-Path $PSScriptRoot "backup.ps1"


Write-Log "Starting final backup."



if (!(Test-Path $Workspace)) {

    Write-Log "Workspace does not exist."

    exit 0
}



Invoke-Retry {

    Write-Log "Executing backup."

    & powershell.exe `
        -ExecutionPolicy Bypass `
        -File $backupScript


    if ($LASTEXITCODE -ne 0) {

        throw "Backup script failed."
    }

}



Write-Log "Running final remote verification."



$remote = Get-Remote



Invoke-Retry {

    & $RcloneExe `
        check `
        $Workspace `
        $remote `
        --config $RcloneConfig `
        --one-way


    if ($LASTEXITCODE -gt 1) {

        throw "Remote verification failed."
    }

}



$stats = Get-WorkspaceStats



Write-Log "Final backup completed."

Write-Log "Files: $($stats.Files)"

Write-Log "Directories: $($stats.Directories)"

Write-Log "Size MB: $($stats.SizeMB)"

Write-Log "Runner can exit safely."



exit 0
