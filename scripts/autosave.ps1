$ErrorActionPreference = 'Continue'

Write-Host "[Autosave] Starting autosave script..."

$intervalSeconds = 600 # 10 minutes
$scriptPath = Join-Path $PSScriptRoot "backup.ps1"

while ($true) {
    Write-Host "[Autosave] Waiting for $intervalSeconds seconds before next backup..."
    Start-Sleep -Seconds $intervalSeconds

    Write-Host "[Autosave] Initiating scheduled backup..."
    try {
        # Execute backup.ps1 as a separate process to ensure it gets its own environment and exit code
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -ne 0) {
            Write-Warning "[Autosave] Backup script exited with non-zero code: $($process.ExitCode). This might indicate a partial failure, but autosave will continue."
        } else {
            Write-Host "[Autosave] Scheduled backup completed successfully."
        }
    } catch {
        Write-Error "[Autosave] Error during scheduled backup: $($_.Exception.Message). Autosave will continue."
    }
}
