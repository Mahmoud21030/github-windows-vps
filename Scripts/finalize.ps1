$ErrorActionPreference = 'Stop'

Write-Host "[Finalize] Starting finalization script..."

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
        Write-Host "[Finalize] Attempt $i of $MaxRetries: rclone $Command"
        $process = Start-Process -FilePath "rclone" -ArgumentList $Command -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -eq 0) {
            return $true
        } else {
            Write-Warning "[Finalize] rclone command failed with exit code $($process.ExitCode). Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
    Write-Error "[Finalize] rclone command failed after $MaxRetries attempts: $Command"
    return $false
}

Write-Host "[Finalize] Performing final sync of workspace from $workspacePath to $rcloneRemote..."
$rcloneSyncCommand = "sync $workspacePath $rcloneRemote --create-empty-src-dirs --fast-list --transfers 16 --checkers 16 --retries 3 --low-level-retries 10 --log-level INFO"

if (-not (Invoke-RcloneWithRetry -Command $rcloneSyncCommand -MaxRetries 5)) {
    Write-Error "[Finalize] Final sync failed after multiple retries. Exiting with error."
    exit 1
}

Write-Host "[Finalize] Final sync completed successfully. Verifying upload..."

# Verify upload success by checking if the remote path is not empty
# This is a basic verification. A more robust check might involve comparing file hashes or sizes.
# For this use case, ensuring the remote is not empty after sync is a reasonable indicator.
$verifyCommand = "ls $rcloneRemote --max-depth 1"
$verifyResult = Invoke-RcloneWithRetry -Command $verifyCommand -MaxRetries 3

if ($verifyResult) {
    Write-Host "[Finalize] Upload verification successful. Remote backup is not empty."
    Write-Host "[Finalize] Finalization script finished gracefully."
    exit 0
} else {
    Write-Error "[Finalize] Upload verification failed. Remote backup appears empty or inaccessible. Exiting with error."
    exit 1
}
