# install.ps1

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

$LogFile = "install.log"

Write-Log "Starting workspace preparation." $LogFile

# create workspace

if (!(Test-Path $Workspace)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $Workspace | Out-Null

    Write-Log "Created workspace directory." $LogFile

}

# create folders

$folders = @(

    "Documents",

    "Downloads",

    "Projects",

    "Installers",

    "Installed",

    "config"

)

foreach ($folder in $folders) {

    $path = Join-Path $Workspace $folder

    if (!(Test-Path $path)) {

        New-Item `
            -ItemType Directory `
            -Force `
            -Path $path | Out-Null

        Write-Log "Created folder: $path" $LogFile

    }

}

# create installer state file

$stateFile = Join-Path $Workspace ".installed"

if (!(Test-Path $stateFile)) {

    New-Item `
        -ItemType File `
        -Path $stateFile `
        -Force | Out-Null

    Write-Log "Created installer state file." $LogFile

}

Write-Log "Checking Windows environment." $LogFile

$os = Get-CimInstance Win32_OperatingSystem

Write-Log "OS: $($os.Caption)" $LogFile

Write-Log "Version: $($os.Version)" $LogFile

Write-Log "PowerShell: $($PSVersionTable.PSVersion)" $LogFile

Write-Log "Workspace: $Workspace" $LogFile

Write-Log "Runtime: $Runtime" $LogFile

Write-Log "Workspace preparation completed." $LogFile
