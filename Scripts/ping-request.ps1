$ipAddress = $args[0]

$pingResult = Test-Connection -ComputerName $ipAddress -Count 1 -Quiet

# Ping sonucuna göre durumu belirle
if ($pingResult) {
    Write-Output 1
} else {
    Write-Output 0
}
