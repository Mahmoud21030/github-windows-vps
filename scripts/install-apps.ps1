$ErrorActionPreference = "Stop"

$workspace = $env:WORKSPACE

if ([string]::IsNullOrWhiteSpace($workspace)) {
    $workspace = "C:\Workspace"
}

$installerFolder = Join-Path $workspace "Installers"
$manifestFile = Join-Path $installerFolder "installers.json"

if (!(Test-Path $installerFolder)) {

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $installerFolder | Out-Null

    Write-Host "Created installer folder."
}

if (!(Test-Path $manifestFile)) {

@'
{
    "applications":[
    ]
}
'@ | Set-Content $manifestFile -Encoding UTF8

    Write-Host "Created installers.json"

    exit 0
}

$json = Get-Content $manifestFile -Raw | ConvertFrom-Json

foreach ($app in $json.applications) {

    $installer = Join-Path $installerFolder $app.file

    if (!(Test-Path $installer)) {

        Write-Host "$($app.file) not found."
        continue
    }

    Write-Host ""
    Write-Host "Installing $($app.file)"

    try {

        if ($installer.ToLower().EndsWith(".msi")) {

            Start-Process `
                msiexec.exe `
                -ArgumentList "/i `"$installer`" $($app.arguments)" `
                -Wait

        }
        else {

            Start-Process `
                -FilePath $installer `
                -ArgumentList $app.arguments `
                -Wait

        }

        Write-Host "$($app.file) installed."

    }
    catch {

        Write-Host "Failed to install $($app.file)"
        Write-Host $_.Exception.Message

    }

}
