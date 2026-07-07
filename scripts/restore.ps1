$ErrorActionPreference = 'Stop'

Write-Host "[Restore] Starting workspace restoration script..."

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
        Write-Host "[Restore] Attempt $i of $MaxRetries: rclone $Command"
        $process = Start-Process -FilePath "rclone" -ArgumentList $Command -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -eq 0) {
            return $true
        } else {
            Write-Warning "[Restore] rclone command failed with exit code $($process.ExitCode). Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    Write-Error "[Restore] rclone command failed after $MaxRetries attempts: $Command"
    return $false
}

# Check if backup exists
Write-Host "[Restore] Checking for existing backup at $rcloneRemote..."
try {
    # Use rclone size to check if the remote path exists and has content
    # If it fails, it means the remote path doesn't exist or is empty
    $checkResult = Invoke-RcloneWithRetry -Command "size $rcloneRemote --json" -MaxRetries 3
    
    if ($checkResult) {
        Write-Host "[Restore] Backup found. Proceeding with download."
        
        # Download and restore workspace
        Write-Host "[Restore] Downloading workspace from $rcloneRemote to $workspacePath..."
        $rcloneSyncCommand = "sync $rcloneRemote $workspacePath --create-empty-src-dirs --fast-list --transfers 16 --checkers 16 --retries 3 --low-level-retries 10 --log-level INFO"
        if (-not (Invoke-RcloneWithRetry -Command $rcloneSyncCommand -MaxRetries 5)) {
            Write-Error "[Restore] Failed to download workspace after multiple retries."
            exit 1
        }
        Write-Host "[Restore] Workspace restoration complete."
    } else {
        Write-Host "[Restore] No backup found or backup is empty. Creating an empty workspace."
        if (-not (Test-Path $workspacePath)) {
            New-Item -Path $workspacePath -ItemType Directory | Out-Null
            Write-Host "[Restore] Empty workspace created at $workspacePath."
        } else {
            Write-Host "[Restore] Workspace directory already exists and is empty."
        }
    }
} catch {
    Write-Warning "[Restore] An error occurred during backup check or download: $($_.Exception.Message)"
    Write-Host "[Restore] Assuming no backup exists and creating an empty workspace."
    if (-not (Test-Path $workspacePath)) {
        New-Item -Path $workspacePath -ItemType Directory | Out-Null
        Write-Host "[Restore] Empty workspace created at $workspacePath."
    }
}

Write-Host "[Restore] Workspace restoration script finished."
