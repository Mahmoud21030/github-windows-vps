$ErrorActionPreference = 'Stop'

Write-Host "[Backup] Starting workspace backup script..."

$workspacePath = "C:\Workspace"
$rcloneRemote = "oci_backup:$env:OCI_BUCKET/workspace_backup"

# Function to execute rclone commands with retry logic
function Invoke-RcloneWithRetry {
    param(
        [string]$Command,
        [int]$MaxRetries = 5,
        [int]$RetryDelaySeconds = 10
    )

    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Host "[Backup] Attempt $i of $MaxRetries: rclone $Command"
        $process = Start-Process -FilePath "rclone" -ArgumentList $Command -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -eq 0) {
            return $true
        } else {
            Write-Warning "[Backup] rclone command failed with exit code $($process.ExitCode). Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    Write-Error "[Backup] rclone command failed after $MaxRetries attempts: $Command"
    return $false
}

Write-Host "[Backup] Syncing workspace from $workspacePath to $rcloneRemote..."
$rcloneSyncCommand = "sync $workspacePath $rcloneRemote --create-empty-src-dirs --fast-list --transfers 16 --checkers 16 --retries 3 --low-level-retries 10 --log-level INFO"

if (-not (Invoke-RcloneWithRetry -Command $rcloneSyncCommand -MaxRetries 5)) {
    Write-Error "[Backup] Failed to sync workspace after multiple retries."
    exit 1
}

Write-Host "[Backup] Workspace backup complete."
