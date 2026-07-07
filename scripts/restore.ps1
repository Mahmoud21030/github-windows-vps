# restore.ps1
# restores workspace from oracle object storage

$ErrorActionPreference = "Stop"

$workspace = "C:\Workspace"
$logDir = Join-Path $workspace "logs"
$logFile = Join-Path $logDir "restore.log"

New-Item -ItemType Directory -Force -Path $workspace | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$rclone = "C:\Tools\rclone\rclone.exe"

if (-not (Test-Path $rclone)) {
    throw "rclone.exe not found at $rclone"
}
$config = Join-Path $workspace "config\rclone.conf"

$remote = "oci:$($env:OCI_BUCKET)/workspace"

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
        [int]$RetryCount = 5,
        [int]$DelaySeconds = 15
    )

    for ($i = 1; $i -le $RetryCount; $i++) {

        try {
            & $Action
            return $true
        }
        catch {

            Write-Log "Attempt $i failed."

            if ($i -eq $RetryCount) {
                Write-Log "Maximum retries reached."
                return $false
            }

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

Write-Log "Starting workspace restore."

$exists = $false

Invoke-WithRetry {

    $output = & $rclone lsf `
        $remote `
        --config $config

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to access bucket."
    }

    if ($output) {
        $script:exists = $true
    }
} | Out-Null

if (-not $exists) {

    Write-Log "No existing backup found."

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $workspace | Out-Null

    Write-Log "Created empty workspace."

    return
}

Write-Log "Backup detected."

$ok = Invoke-WithRetry {

    & $rclone sync `
        $remote `
        $workspace `
        --config $config `
        --create-empty-src-dirs `
        --transfers 8 `
        --checkers 8 `
        --fast-list `
        --retries 5 `
        --retries-sleep 10s `
        --low-level-retries 10 `
        --copy-links `
        --links `
        --metadata `
        --progress `
        --stats 30s

    if ($LASTEXITCODE -ne 0) {
        throw "Restore failed."
    }

}

if (-not $ok) {
    throw "Workspace restore failed after multiple retries."
}

Write-Log "Verifying restored files."

$verify = Invoke-WithRetry {

    & $rclone check `
        $remote `
        $workspace `
        --config $config `
        --one-way

    if ($LASTEXITCODE -gt 1) {
        throw "Verification failed."
    }

}

if (-not $verify) {
    throw "Restore verification failed."
}

$fileCount = (Get-ChildItem `
    -Path $workspace `
    -File `
    -Recurse `
    -ErrorAction SilentlyContinue).Count

$folderCount = (Get-ChildItem `
    -Path $workspace `
    -Directory `
    -Recurse `
    -ErrorAction SilentlyContinue).Count

Write-Log ""
Write-Log "Restore completed successfully."
Write-Log "Files restored : $fileCount"
Write-Log "Folders        : $folderCount"
Write-Log ""
