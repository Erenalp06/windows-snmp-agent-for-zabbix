$server = "<your-zabbix-server-ip-address>"

#Download address definitions
$version = "https://cdn.zabbix.com/zabbix/binaries/stable/6.0/6.0.28/zabbix_agent-6.0.28-windows-amd64-openssl.zip"
$vRedistInstallerUrl = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
$snmpwalk = 
#Script path definitions
$ping = "https://raw.githubusercontent.com/limanmys/zabbix-agent-slient/main/Scripts/ping-request.ps1"
$snmpv2 = "https://raw.githubusercontent.com/limanmys/zabbix-agent-slient/main/Scripts/snmpv2-request.ps1"
$snmpv3 = "https://raw.githubusercontent.com/limanmys/zabbix-agent-slient/main/Scripts/snmpv3-request.ps1"

$zabbixAgentDirectory = "C:\Program Files\zabbix-agent"

# Create directory for scripts
New-Item -Path "$zabbixAgentDirectory\Scripts" -ItemType Directory -Force
New-Item -Path "$zabbixAgentDirectory\Logs" -ItemType Directory -Force

# vc_redist.x64 installation
Invoke-WebRequest -Uri $vRedistInstallerUrl -OutFile "$zabbixAgentDirectory\vc_redist.x64.exe"
Start-Process -FilePath "$zabbixAgentDirectory\vc_redist.x64.exe" -ArgumentList "/quiet", "/norestart" -Wait

# Zabbix Agent installation
Invoke-WebRequest -Uri $version -OutFile "$zabbixAgentDirectory\zabbix.zip"
Expand-Archive -Path "$zabbixAgentDirectory\zabbix.zip" -DestinationPath "$zabbixAgentDirectory"

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Unzip "$zabbixAgentDirectory\zabbix.zip" "$zabbixAgentDirectory"


# Download scripts
Invoke-WebRequest -Uri $ping -OutFile "$zabbixAgentDirectory\Scripts\ping-request.ps1"
Invoke-WebRequest -Uri $snmpv2 -OutFile "$zabbixAgentDirectory\Scripts\snmpv2-request.ps1"
Invoke-WebRequest -Uri $snmpv3 -OutFile "$zabbixAgentDirectory\Scripts\snmpv3-request.ps1"


# Update zabbix_agentd.conf
    
$linesToAdd = @'
LogFile=C:\Program Files\zabbix-agent\Logs\zabbix_agentd.log

LogFile=C:\Program Files\zabbix-agent\Logs\zabbix_agentd.log
LogFileSize=1
DebugLevel=3

Server=<your-ip>

ServerActive=<your-ip>

Hostname=Windows host

RefreshActiveChecks=120
BufferSend=5
BufferSize=100
MaxLinesPerSecond=20

UserParameter=deren.ping[*],powershell.exe -File "C:\Program Files\zabbix-agent\Scripts\ping-request.ps1" $1
UserParameter=deren.snmp[*],powershell.exe -File "C:\Program Files\zabbix-agent\Scripts\snmpv2-request.ps1" $1 $2 $3
UserParameter=deren.snmpv3[*],powershell.exe -File "C:\Program Files\zabbix-agent\Scripts\snmpv3-request.ps1" $1 $2 $3 $4 $5 $6 $7
'@

Set-Content -Path "$zabbixAgentDirectory\conf\zabbix_agentd.conf" -Value $linesToAdd
(Get-Content -Path "$zabbixAgentDirectory\conf\zabbix_agentd.conf") | ForEach-Object {$_ -Replace '<your-ip>', "$server"} | Set-Content -Path "$zabbixAgentDirectory\conf\zabbix_agentd.conf"


# Install and start Zabbix Agent
& "$zabbixAgentDirectory\bin\zabbix_agentd.exe" --config "$zabbixAgentDirectory\conf\zabbix_agentd.conf" --install
New-NetFirewallRule -DisplayName "Zabbix Agent Rule" -Direction Inbound -LocalPort 10050 -Protocol TCP -Action Allow

& "$zabbixAgentDirectory\bin\zabbix_agentd.exe" --start --config "$zabbixAgentDirectory\conf\zabbix_agentd.conf"
