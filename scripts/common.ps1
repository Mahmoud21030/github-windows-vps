# common.ps1

$ErrorActionPreference = "Stop"


$Global:Workspace = "C:\Workspace"

$Global:RuntimeDir = "C:\ProgramData\github-workspace"

$Global:LogDir = Join-Path $RuntimeDir "logs"

$Global:ConfigDir = $RuntimeDir

$Global:RcloneExe = "C:\Tools\rclone\rclone.exe"

$Global:RcloneConfig = Join-Path $RuntimeDir "rclone.conf"



New-Item `
    -ItemType Directory `
    -Force `
    -Path $Workspace | Out-Null


New-Item `
    -ItemType Directory `
    -Force `
    -Path $RuntimeDir | Out-Null


New-Item `
    -ItemType Directory `
    -Force `
    -Path $LogDir | Out-Null



function Start-Log {

    param(
        [string]$Name
    )

    $script:LogFile = Join-Path $LogDir "$Name.log"

}



function Write-Log {

    param(
        [string]$Message
    )


    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $line = "[$time] $Message"


    Write-Host $line


    if ($script:LogFile) {

        $folder = Split-Path $script:LogFile -Parent

        if (!(Test-Path $folder)) {

            New-Item `
                -ItemType Directory `
                -Force `
                -Path $folder | Out-Null
        }


        Add-Content `
            -Path $script:LogFile `
            -Value $line
    }
}



function Invoke-Retry {

    param(
        [scriptblock]$Script,
        [int]$Retries = 5,
        [int]$DelaySeconds = 10
    )


    for ($i = 1; $i -le $Retries; $i++) {


        try {

            Write-Log "Attempt $i"

            & $Script

            return

        }
        catch {

            Write-Log $_.Exception.Message


            if ($i -eq $Retries) {

                throw
            }


            Start-Sleep `
                -Seconds $DelaySeconds
        }
    }
}



function Get-Rclone {

    if (!(Test-Path $RcloneExe)) {

        throw "rclone not found: $RcloneExe"
    }


    return $RcloneExe
}



function Invoke-Rclone {

    param(
        [string[]]$Arguments
    )


    $exe = Get-Rclone


    & $exe `
        @Arguments


    if ($LASTEXITCODE -ne 0) {

        throw "rclone exited with code $LASTEXITCODE"
    }
}



function Get-Remote {

    return "oci:$($env:OCI_BUCKET)/workspace"
}



function Get-WorkspaceStats {


    $files = Get-ChildItem `
        $Workspace `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue


    [PSCustomObject]@{

        Files = $files.Count

        SizeMB = [math]::Round(
            (($files | Measure-Object Length -Sum).Sum / 1MB),
            2
        )
    }
}
