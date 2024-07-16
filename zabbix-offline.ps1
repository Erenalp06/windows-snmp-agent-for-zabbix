 
# Yönetici iznini kontrol et ve gerekirse talep et
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "This script needs to be run as an Administrator. Please restart PowerShell as an Administrator."
    exit
}

# Zabbix sunucu IP adreslerini ve hostname'i belirleyin
$ZABBIX_SERVER_IP = "<YOUR_ZABBIX_SERVER_IP>"

# Dizin ve dosya yollarını belirleyin
$zabbixAgentDirectory = "C:\Program Files\zabbix-agent"
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$zipFile = Join-Path -Path $scriptDirectory -ChildPath "zabbix-agent.zip"

# Program Files içinde Zabbix Agent dizinini oluşturun
if (-not (Test-Path $zabbixAgentDirectory)) {
    New-Item -ItemType Directory -Path $zabbixAgentDirectory -Force | Out-Null
}

# Zabbix Agent ZIP dosyasını çıkarın
if (Test-Path $zipFile) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $zabbixAgentDirectory)
    Write-Host "Extraction completed."
} else {
    Write-Host "Zip file not found: $zipFile"
    exit
}

# Gerekli bağımlılıkları kopyalayın
Copy-Item -Path "$scriptDirectory\vc_redist.x64.exe" -Destination $zabbixAgentDirectory -Force
Copy-Item -Path "$scriptDirectory\snmpwalk.exe" -Destination $zabbixAgentDirectory -Force

# Zabbix Agent servisinin kaldırılması (varsa)
if (Get-Service -Name "Zabbix Agent" -ErrorAction SilentlyContinue) {
    sc stop "Zabbix Agent"
    sc delete "Zabbix Agent"
    Start-Sleep -Seconds 10 # Kaldırma işleminin tamamlanması için bekleyin
}

# Çıkarılan dosyaların doğru yerde olduğunu kontrol edin
if (-not (Test-Path "$zabbixAgentDirectory\conf\zabbix_agentd.conf") -or -not (Test-Path "$zabbixAgentDirectory\bin\zabbix_agentd.exe")) {
    Write-Host "Required files are missing. Please check the ZIP file and extraction path."
    exit
}

# Visual C++ Redistributable'ın kurulumu
if (Test-Path "$zabbixAgentDirectory\vc_redist.x64.exe") {
    Start-Process -FilePath "$zabbixAgentDirectory\vc_redist.x64.exe" -ArgumentList "/quiet", "/norestart" -Wait
} else {
    Write-Host "vc_redist.x64.exe not found in $zabbixAgentDirectory"
    exit
}

# Konfigürasyon dosyasının düzenlenmesi
$configPath = "$zabbixAgentDirectory\conf\zabbix_agentd.conf"
if (Test-Path $configPath) {
    (Get-Content $configPath) `
	-replace 'Server=127.0.0.1', "Server=$ZABBIX_SERVER_IP" `
        | Set-Content $configPath

    # Dosyanın doğru şekilde değiştirildiğini doğrulayın
    $updatedContent = Get-Content -Path $configPath
    Write-Host "Updated configuration file content:"
    Write-Host $updatedContent
} else {
    Write-Host "Configuration file not found: $configPath"
    exit
}

# Zabbix Agent'in kurulması ve başlatılması
& "$zabbixAgentDirectory\bin\zabbix_agentd.exe" --config "$zabbixAgentDirectory\conf\zabbix_agentd.conf" --install

# Güvenlik duvarı kuralının eklenmesi
New-NetFirewallRule -DisplayName "Zabbix Agent Rule" -Direction Inbound -LocalPort 10050 -Protocol TCP -Action Allow

# SNMPwalk aracının kontrol edilmesi ve PATH'e eklenmesi
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$snmpwalkDirectory = "$zabbixAgentDirectory"
$snmpwalkFilePath = "$zabbixAgentDirectory\snmpwalk.exe"

if (-not (Test-Path -Path $snmpwalkFilePath)) {
    Write-Host "snmpwalk.exe not found in $snmpwalkDirectory"
    exit
}

if ($currentPath -notlike "*$snmpwalkDirectory*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$snmpwalkDirectory", "Machine")
    Write-Host "Directory added to PATH. You can now use 'snmpwalk' command."
} else {
    Write-Host "Directory is already in PATH."
}

# Zabbix Agent'in başlatılması
& "$zabbixAgentDirectory\bin\zabbix_agentd.exe" --start --config "$zabbixAgentDirectory\conf\zabbix_agentd.conf"
