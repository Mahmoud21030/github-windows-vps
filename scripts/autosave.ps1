# autosave.ps1

. "$PSScriptRoot\common.ps1"

Start-Log "autosave"


$backupScript = Join-Path $PSScriptRoot "backup.ps1"


function Get-WorkspaceFingerprint {


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



$lastFingerprint = Get-WorkspaceFingerprint



while ($true) {


    Start-Sleep -Seconds 600



    try {


        $currentFingerprint = Get-WorkspaceFingerprint



        if ($currentFingerprint -eq $lastFingerprint) {


            Write-Log "No workspace changes detected."

            continue

        }



        Write-Log "Workspace changes detected."



        powershell.exe `
            -ExecutionPolicy Bypass `
            -File $backupScript



        if ($LASTEXITCODE -eq 0) {


            $lastFingerprint = $currentFingerprint

            Write-Log "Autosave completed."

        }
        else {

            Write-Log "Autosave backup failed."

        }


    }
    catch {

        Write-Log $_.Exception.Message

    }

}
