$ErrorActionPreference = 'Stop'

Write-Host "[Cloudflare-Tunnel] Starting Cloudflare Tunnel setup script..."

$cloudflaredInstallPath = "C:\cloudflared"
$cloudflaredExe = Join-Path $cloudflaredInstallPath "cloudflared.exe"
$cloudflaredDownloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi"

# 1. Download and install cloudflared
Write-Host "[Cloudflare-Tunnel] Downloading cloudflared from $cloudflaredDownloadUrl..."
try {
    Invoke-WebRequest -Uri $cloudflaredDownloadUrl -OutFile "cloudflared.msi"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i cloudflared.msi /quiet /qn /norestart" -Wait
    # The MSI installs to Program Files, let's ensure it's in PATH or use its full path
    # For simplicity, we'll assume it's in PATH after MSI install or find it.
    # A more robust approach would be to copy it to a known location and add that to PATH.
    # For now, let's rely on the MSI adding it to PATH or finding it in Program Files.
    
    # Verify installation by checking if cloudflared.exe exists in Program Files
    $programFilesCloudflared = Get-ChildItem -Path "$env:ProgramFiles\Cloudflare\cloudflared" -Filter "cloudflared.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    if (-not $programFilesCloudflared) {
        Write-Error "[Cloudflare-Tunnel] cloudflared.exe not found after MSI installation."
        exit 1
    }
    $cloudflaredExe = $programFilesCloudflared # Update path to the actual installed location
    Write-Host "[Cloudflare-Tunnel] cloudflared installed to $cloudflaredExe"

} catch {
    Write-Error "[Cloudflare-Tunnel] Failed to download or install cloudflared: $($_.Exception.Message)"
    exit 1
}

# 2. Authenticate cloudflared and run the tunnel
# The CLOUDFLARE_TUNNEL_TOKEN is expected to be a GitHub Secret
$cloudflareTunnelToken = $env:CLOUDFLARE_TUNNEL_TOKEN
$cloudflareTunnelHostname = $env:CLOUDFLARE_TUNNEL_HOSTNAME

if ([string]::IsNullOrEmpty($cloudflareTunnelToken)) {
    Write-Error "[Cloudflare-Tunnel] CLOUDFLARE_TUNNEL_TOKEN environment variable is not set. Cannot start Cloudflare Tunnel."
    exit 1
}

if ([string]::IsNullOrEmpty($cloudflareTunnelHostname)) {
    Write-Error "[Cloudflare-Tunnel] CLOUDFLARE_TUNNEL_HOSTNAME environment variable is not set. Cannot start Cloudflare Tunnel."
    exit 1
}

Write-Host "[Cloudflare-Tunnel] Starting Cloudflare Tunnel for RDP..."
Write-Host "[Cloudflare-Tunnel] Tunnel will be accessible via: $cloudflareTunnelHostname"

# Run cloudflared tunnel as a background process
# The --url specifies the local service to expose (RDP on port 3389)
# The --hostname specifies the public hostname to use
# The --token is for authentication

# We need to run this in a way that it doesn't block the script but keeps the tunnel alive.
# Using Start-Job is an option, but for a long-running process that needs to stay active
# throughout the GitHub Actions job, it's better to run it directly and let the GA job manage its lifecycle.
# However, the 'Keep Alive' step will be blocking, so we can run cloudflared in the background.

# Create a tunnel configuration file dynamically
$tunnelConfigDir = Join-Path $env:USERPROFILE ".cloudflared"
if (-not (Test-Path $tunnelConfigDir)) {
    New-Item -Path $tunnelConfigDir -ItemType Directory | Out-Null
}
$tunnelConfigFile = Join-Path $tunnelConfigDir "config.yml"

$configContent = @"
hostname: $cloudflareTunnelHostname
url: rdp://localhost:3389
token: $cloudflareTunnelToken
"@
$configContent | Set-Content -Path $tunnelConfigFile

Write-Host "[Cloudflare-Tunnel] Cloudflare Tunnel config written to $tunnelConfigFile"

# Start cloudflared tunnel in a new process, detached from the current PowerShell session
# This allows the script to finish while the tunnel keeps running.
# We need to ensure it runs with the correct token and configuration.

# Using Start-Process with -NoNewWindow and -PassThru and then waiting for it is not ideal for background.
# A better approach for background execution that persists is to use `Start-Job` or `Start-Process` with redirection.
# For GitHub Actions, we can just run it and let the GA step manage it.
# The `Keep Alive` step will be the one that keeps the overall job running.

# Let's simplify: run cloudflared directly and let it block, or run it in background and ensure it stays alive.
# For a workstation, the tunnel needs to be active during the 'Keep Alive' phase.
# The current `Keep Alive` step uses `Start-Sleep`, so `cloudflared` needs to run in the background.

# Start cloudflared as a background job
Write-Host "[Cloudflare-Tunnel] Starting cloudflared tunnel as a background job..."
Start-Job -ScriptBlock {
    param($cloudflaredExe, $tunnelConfigFile)
    $ErrorActionPreference = 'Continue'
    Write-Host "[Cloudflare-Tunnel-Job] Cloudflared background job started."
    & $cloudflaredExe tunnel --config $tunnelConfigFile run
    Write-Host "[Cloudflare-Tunnel-Job] Cloudflared background job finished."
} -ArgumentList $cloudflaredExe, $tunnelConfigFile -Name "CloudflareTunnel"

Write-Host "[Cloudflare-Tunnel] Cloudflare Tunnel setup script finished. Tunnel should be running in background."
