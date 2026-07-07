# backup.ps1
# syncs changed files from the workspace to oracle object storage

$ErrorActionPreference = "Stop"

$workspace = "C:\Workspace"
$logDir = Join-Path $workspace "logs"
$logFile = Join-Path $logDir "backup.log"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$rclone = "C:\Tools\rclone\rclone.exe"

if (-not (Test-Path $rclone)) {

    $cmd = Get-Command rclone.exe -ErrorAction SilentlyContinue

    if ($cmd) {
        $rclone = $cmd.Source
    }
    else {
        throw "rclone.exe was not found."
    }
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
                Write-Log "Backup failed after $RetryCount attempts."
                return $false
            }

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

if (-not (Test-Path $workspace)) {
    throw "Workspace directory does not exist."
}

Write-Log "Starting incremental backup."

$success = Invoke-WithRetry {

    & $rclone sync `
        $workspace `
        $remote `
        --config $config `
        --create-empty-src-dirs `
        --fast-list `
        --transfers 8 `
        --checkers 8 `
        --copy-links `
        --links `
        --metadata `
        --track-renames `
        --retries 5 `
        --retries-sleep 10s `
        --low-level-retries 10 `
        --stats 30s `
        --stats-one-line

    if ($LASTEXITCODE -ne 0) {
        throw "rclone sync returned exit code $LASTEXITCODE."
    }
}

if (-not $success) {
    throw "Incremental backup failed."
}

Write-Log "Verifying uploaded files."

$verify = Invoke-WithRetry {

    & $rclone check `
        $workspace `
        $remote `
        --config $config `
        --one-way

    if ($LASTEXITCODE -gt 1) {
        throw "Verification failed."
    }
}

if (-not $verify) {
    throw "Backup verification failed."
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
Write-Log "Backup completed successfully."
Write-Log "Files    : $fileCount"
Write-Log "Folders  : $folderCount"
Write-Log ""
