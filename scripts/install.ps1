# install.ps1
# prepares the restored workspace environment

. "$PSScriptRoot\common.ps1"

Start-Log "install"


Write-Log "Starting workspace preparation."



if (!(Test-Path $Workspace)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $Workspace | Out-Null
}



$requiredDirs = @(

    $Workspace

    (Join-Path $Workspace "logs")

    (Join-Path $Workspace "config")

)



foreach ($dir in $requiredDirs) {


    if (!(Test-Path $dir)) {


        New-Item `
            -ItemType Directory `
            -Force `
            -Path $dir | Out-Null


        Write-Log "Created directory: $dir"

    }

}



Write-Log "Checking Windows environment."


$os = Get-CimInstance `
    Win32_OperatingSystem


Write-Log "Operating system: $($os.Caption)"



Write-Log "PowerShell version: $($PSVersionTable.PSVersion)"



Write-Log "Workspace preparation completed."
