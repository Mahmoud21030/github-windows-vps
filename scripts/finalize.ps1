# finalize.ps1

. "$PSScriptRoot\common.ps1"

Start-Log "finalize"


$backupScript = Join-Path $PSScriptRoot "backup.ps1"


Write-Log "Starting final backup."



try {


    Invoke-Retry {


        Write-Log "Running backup script."


        powershell.exe `
            -ExecutionPolicy Bypass `
            -File $backupScript


        if ($LASTEXITCODE -ne 0) {

            throw "Backup script failed."

        }


    }



    Write-Log "Running final verification."


    $remote = Get-Remote



    Invoke-Retry {


        & $RcloneExe `
            check `
            $Workspace `
            $remote `
            --config $RcloneConfig `
            --one-way



        if ($LASTEXITCODE -gt 1) {

            throw "Final verification failed."

        }


    }



    $stats = Get-WorkspaceStats


    Write-Log "Final backup completed."

    Write-Log "Files: $($stats.Files)"

    Write-Log "Directories: $($stats.Directories)"

    Write-Log "Size MB: $($stats.SizeMB)"

    Write-Log "Runner can exit safely."


    exit 0


}
catch {


    Write-Log "Final backup failed."

    Write-Log $_.Exception.Message


    exit 1

}
