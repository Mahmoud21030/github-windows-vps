# finalize.ps1
# performs final workspace backup before github actions shutdown

$ErrorActionPreference = "Stop"

$workspace = "C:\Workspace"
$logDir = Join-Path $workspace "logs"
$logFile = Join-Path $logDir "finalize.log"

$backupScript = Join-Path $PSScriptRoot "backup.ps1"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Write-Log {
    param([string]$Message)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] $Message"

    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Invoke-WithRetry {
    param(
        [scriptblock]$Action,
        [int]$Retries = 5,
        [int]$DelaySeconds = 20
    )

    for ($i = 1; $i -le $Retries; $i++) {

        try {

            & $Action
            return $true

        }
        catch {

            Write-Log "Attempt $i failed."
            Write-Log $_.Exception.Message

            if ($i -eq $Retries) {
                return $false
            }

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

Write-Log "Starting final backup."

if (-not (Test-Path $workspace)) {

    Write-Log "Workspace does not exist."
    Write-Log "Nothing to backup."

    exit 0
}

$backupSuccess = Invoke-WithRetry {

    Write-Log "Running backup script."

    & powershell `
        -ExecutionPolicy Bypass `
        -File $backupScript

    if ($LASTEXITCODE -ne 0) {

        throw "Backup script returned exit code $LASTEXITCODE."
    }

}

if (-not $backupSuccess) {

    Write-Log "Final backup failed."

    throw "Unable to complete final backup."
}

Write-Log "Running final upload verification."

$config = Join-Path $workspace "config\rclone.conf"
$rclone = (Get-Command rclone.exe -ErrorAction Stop).Source

$remote = "oci:$($env:OCI_BUCKET)/workspace"

$verifySuccess = Invoke-WithRetry {

    & $rclone check `
        $workspace `
        $remote `
        --config $config `
        --one-way

    if ($LASTEXITCODE -gt 1) {

        throw "Remote verification failed."
    }

}

if (-not $verifySuccess) {

    Write-Log "Final verification failed."

    throw "Final backup verification failed."
}

Write-Log ""
Write-Log "================================"
Write-Log " Final backup completed."
Write-Log " Workspace preserved."
Write-Log " Workflow can exit safely."
Write-Log "================================"
Write-Log ""

exit 0
