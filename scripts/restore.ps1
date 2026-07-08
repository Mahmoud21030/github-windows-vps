$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

Write-Log "Starting restore." "restore.log"

# create folders

$null = New-Item `
    -ItemType Directory `
    -Force `
    -Path $Workspace

$null = New-Item `
    -ItemType Directory `
    -Force `
    -Path $InstallerFolder

$null = New-Item `
    -ItemType Directory `
    -Force `
    -Path $InstalledFolder

# ------------------------
# restore workspace
# ------------------------

try {

    Write-Log "Checking workspace backup..." "restore.log"

    Invoke-Retry {

        Invoke-RcloneRestore `
            -Remote (Get-WorkspaceRemote) `
            -Local $Workspace

    }

    Write-Log "Workspace restored." "restore.log"

}
catch {

    Write-Log "Workspace backup not found." "restore.log"

}

# ------------------------
# restore installers
# ------------------------

try {

    Write-Log "Checking installer backup..." "restore.log"

    Invoke-Retry {

        Invoke-RcloneRestore `
            -Remote (Get-InstallerRemote) `
            -Local $InstallerFolder

    }

    Write-Log "Installers restored." "restore.log"

}
catch {

    Write-Log "Installer backup not found." "restore.log"

}

# ------------------------
# create state file
# ------------------------

$stateFile = Join-Path $Workspace ".installed"

if (!(Test-Path $stateFile)) {

    New-Item `
        -ItemType File `
        -Path $stateFile `
        -Force | Out-Null

    Write-Log "Created .installed state file." "restore.log"

}

# ------------------------
# create installer folder
# ------------------------

if (!(Test-Path $InstallerFolder)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $InstallerFolder | Out-Null

}

# ------------------------
# summary
# ------------------------

$installerCount = 0

if (Test-Path $InstallerFolder) {

    $installerCount = (
        Get-ChildItem `
            $InstallerFolder `
            -File `
            -ErrorAction SilentlyContinue
    ).Count

}

Write-Log "Installer count: $installerCount" "restore.log"

Write-Log "Restore completed." "restore.log"
