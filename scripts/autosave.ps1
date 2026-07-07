# autosave.ps1
# checks workspace changes and triggers backups periodically

. "$PSScriptRoot\common.ps1"

Start-Log "autosave"


$backupScript = Join-Path $PSScriptRoot "backup.ps1"


function Get-WorkspaceHash {

    if (!(Test-Path $Workspace)) {

        return ""
    }


    $items = Get-ChildItem `
        -Path $Workspace `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName


    $builder = New-Object System.Text.StringBuilder


    foreach ($item in $items) {

        [void]$builder.Append($item.FullName)

        [void]$builder.Append("|")

        [void]$builder.Append($item.Length)

        [void]$builder.Append("|")

        [void]$builder.Append($item.LastWriteTimeUtc.Ticks)

        [void]$builder.Append("`n")
    }


    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
        $builder.ToString()
    )


    $sha = [System.Security.Cryptography.SHA256]::Create()


    try {

        $hash = $sha.ComputeHash($bytes)

        return (
            [BitConverter]::ToString($hash)
        ).Replace("-", "")

    }
    finally {

        $sha.Dispose()
    }
}



Write-Log "Autosave started."

Write-Log "Interval: 10 minutes"



$lastHash = Get-WorkspaceHash



while ($true) {


    Start-Sleep -Seconds 600


    try {


        $currentHash = Get-WorkspaceHash



        if ($currentHash -eq $lastHash) {


            Write-Log "No changes detected."

            continue
        }



        Write-Log "Changes detected."

        Write-Log "Starting backup."



        & powershell.exe `
            -ExecutionPolicy Bypass `
            -File $backupScript



        if ($LASTEXITCODE -eq 0) {


            $lastHash = $currentHash


            Write-Log "Autosave completed."

        }
        else {

            Write-Log "Backup failed with exit code $LASTEXITCODE."

        }


    }
    catch {

        Write-Log $_.Exception.Message

    }

}
