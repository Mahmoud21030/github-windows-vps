$ErrorActionPreference = 'Stop'

Write-Host "[Enable-RDP] Starting RDP enablement and user configuration script..."

# 1. Enable RDP in the Registry
Write-Host "[Enable-RDP] Enabling Remote Desktop in the registry..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Force
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -Value 3389 -Force

# 2. Configure Windows Firewall to allow RDP connections
Write-Host "[Enable-RDP] Configuring Windows Firewall to allow RDP..."
New-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" -Direction Inbound -LocalPort 3389 -Protocol TCP -Action Allow -Force
New-NetFirewallRule -DisplayName "Remote Desktop (UDP-In)" -Direction Inbound -LocalPort 3389 -Protocol UDP -Action Allow -Force

# 3. Create a new local user for RDP access
$rdpUsername = "ghrunner"
$rdpPassword = $env:RDP_PASSWORD

if ([string]::IsNullOrEmpty($rdpPassword)) {
    Write-Error "[Enable-RDP] RDP_PASSWORD environment variable is not set. Cannot create RDP user."
    exit 1
}

Write-Host "[Enable-RDP] Creating RDP user '$rdpUsername'..."
# Check if user already exists
$userExists = ([ADSI]"WinNT://./$rdpUsername,user" -ne $null)
if (-not $userExists) {
    net user $rdpUsername $rdpPassword /add /y
    Write-Host "[Enable-RDP] User '$rdpUsername' created."
} else {
    Write-Host "[Enable-RDP] User '$rdpUsername' already exists. Updating password."
    net user $rdpUsername $rdpPassword
}

# 4. Add the user to the "Remote Desktop Users" group
Write-Host "[Enable-RDP] Adding user '$rdpUsername' to 'Remote Desktop Users' group..."
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $rdpUsername

Write-Host "[Enable-RDP] RDP enablement and user configuration script finished."
