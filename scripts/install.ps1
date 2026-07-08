# install.ps1

. "$PSScriptRoot\common.ps1"

Start-Log "install"


Write-Log "Starting workspace preparation."


if (!(Test-Path $Workspace)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $Workspace | Out-Null

    Write-Log "Created workspace directory."

}



$folders = @(

    "Documents",

    "Downloads",

    "Projects"

)



foreach ($folder in $folders) {


    $path = Join-Path $Workspace $folder


    if (!(Test-Path $path)) {


        New-Item `
            -ItemType Directory `
            -Force `
            -Path $path | Out-Null


        Write-Log "Created: $path"

    }

}



Write-Log "Checking Windows environment."


$os = Get-CimInstance `
    Win32_OperatingSystem


Write-Log "OS: $($os.Caption)"

Write-Log "PowerShell: $($PSVersionTable.PSVersion)"



Write-Log "Workspace preparation completed."
