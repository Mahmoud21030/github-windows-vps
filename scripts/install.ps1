$ErrorActionPreference = 'Stop'

Write-Host "[Install] Starting installation script..."

# Create C:\Workspace if it doesn't exist
$workspacePath = "C:\Workspace"
if (-not (Test-Path $workspacePath)) {
    Write-Host "[Install] Creating workspace directory: $workspacePath"
    New-Item -Path $workspacePath -ItemType Directory | Out-Null
} else {
    Write-Host "[Install] Workspace directory already exists: $workspacePath"
}

Write-Host "[Install] Installation script finished."
