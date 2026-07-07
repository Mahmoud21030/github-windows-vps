# autosave.ps1
# watches the workspace and runs backup only when changes are detected

$ErrorActionPreference = "Continue"

$workspace = "C:\Workspace"
$logDir = Join-Path $workspace "logs"
$logFile = Join-Path $logDir "autosave.log"

$backupScript = Join-Path $PSScriptRoot "backup.ps1"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Write-Log {
    param([string]$Message)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] $Message"

    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Get-WorkspaceState {

    if (-not (Test-Path $workspace)) {
        return ""
    }

    $builder = New-Object System.Text.StringBuilder

    Get-ChildItem `
        -Path $workspace `
        -Recurse `
        -Force `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object {

            [void]$builder.Append($_.FullName)
            [void]$builder.Append("|")
            [void]$builder.Append($_.Length)
            [void]$builder.Append("|")
            [void]$builder.Append($_.LastWriteTimeUtc.Ticks)
            [void]$builder.Append("`n")
        }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())

    $sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash)).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

Write-Log "Autosave service started."
Write-Log "Monitoring: $workspace"
Write-Log "Interval : 10 minutes"

$lastHash = Get-WorkspaceState

while ($true) {

    Start-Sleep -Seconds 600

    try {

        if (-not (Test-Path $workspace)) {
            Write-Log "Workspace not found."
            continue
        }

        $currentHash = Get-WorkspaceState

        if ($currentHash -eq $lastHash) {

            Write-Log "No changes detected."
            continue
        }

        Write-Log "Changes detected."
        Write-Log "Starting backup."

        & powershell `
            -ExecutionPolicy Bypass `
            -File $backupScript

        if ($LASTEXITCODE -eq 0) {

            $lastHash = $currentHash
            Write-Log "Backup completed successfully."
        }
        else {

            Write-Log "Backup returned exit code $LASTEXITCODE."
        }

    }
    catch {

        Write-Log "Autosave error:"
        Write-Log $_.Exception.Message
    }

}
