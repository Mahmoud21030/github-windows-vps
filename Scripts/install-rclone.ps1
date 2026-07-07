$ErrorActionPreference = 'Stop'

Write-Host "[Install-Rclone] Starting rclone installation script..."

$rcloneDownloadUrl = "https://rclone.org/downloads/"
$rcloneZipFile = "rclone-windows-amd64.zip"
$rcloneExtractDir = "rclone-windows-amd64"
$rcloneInstallPath = "C:\rclone"

Write-Host "[Install-Rclone] Fetching latest rclone download URL..."
try {
    $html = Invoke-WebRequest -Uri $rcloneDownloadUrl -UseBasicParsing
    $latestRcloneLink = ($html.Links | Where-Object { $_.href -like '*windows-amd64.zip' } | Select-Object -First 1).href
    if (-not $latestRcloneLink) {
        Write-Error "[Install-Rclone] Could not find latest rclone download link."
        exit 1
    }
    $fullDownloadUrl = "https://rclone.org" + $latestRcloneLink
    Write-Host "[Install-Rclone] Found latest rclone: $fullDownloadUrl"
} catch {
    Write-Error "[Install-Rclone] Failed to fetch rclone download URL: $($_.Exception.Message)"
    exit 1
}

Write-Host "[Install-Rclone] Downloading rclone from $fullDownloadUrl..."
try {
    Invoke-WebRequest -Uri $fullDownloadUrl -OutFile $rcloneZipFile
} catch {
    Write-Error "[Install-Rclone] Failed to download rclone: $($_.Exception.Message)"
    exit 1
}

Write-Host "[Install-Rclone] Extracting rclone..."
try {
    Expand-Archive -Path $rcloneZipFile -DestinationPath . -Force
} catch {
    Write-Error "[Install-Rclone] Failed to extract rclone: $($_.Exception.Message)"
    exit 1
}

Write-Host "[Install-Rclone] Moving rclone to $rcloneInstallPath..."
try {
    if (Test-Path $rcloneInstallPath) {
        Remove-Item -Path $rcloneInstallPath -Recurse -Force
    }
    Move-Item -Path "$rcloneExtractDir" -Destination $rcloneInstallPath -Force
} catch {
    Write-Error "[Install-Rclone] Failed to move rclone: $($_.Exception.Message)"
    exit 1
}

Write-Host "[Install-Rclone] Adding rclone to PATH..."
$env:Path = "$rcloneInstallPath;$env:Path"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Process)

Write-Host "[Install-Rclone] Verifying rclone installation..."
try {
    rclone version
} catch {
    Write-Error "[Install-Rclone] rclone command not found after installation. $($_.Exception.Message)"
    exit 1
}

Write-Host "[Install-Rclone] rclone installation script finished."
