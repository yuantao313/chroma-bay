# Query device maintenance status over CDC (requires DTR asserted for TinyUSB TX).
param([string]$Port = "", [string]$VidPid = "VID_1209&PID_A16C", [int]$TimeoutMs = 3000)
if ($Port -eq "") {
    $dev = Get-PnpDevice | Where-Object { $_.InstanceId -match $VidPid -and $_.Class -eq 'Ports' -and $_.Status -eq 'OK' } | Select-Object -First 1
    if ($dev -and $dev.FriendlyName -match '\((COM\d+)\)') { $Port = $Matches[1] }
    if ($Port -eq "") { Write-Output "NO-DEVICE"; exit 1 }
}
$sp = New-Object System.IO.Ports.SerialPort($Port, 115200)
$sp.ReadTimeout = $TimeoutMs
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.Open()
Start-Sleep -Milliseconds 500
$sp.DiscardInBuffer()
$sp.Write("?")
$deadline = (Get-Date).AddMilliseconds($TimeoutMs)
$resp = ""
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 100
    $resp += $sp.ReadExisting()
    if ($resp -match "STAT") { break }
}
$sp.Close()
if ($resp -eq "") { Write-Output "NO-RESPONSE" } else { Write-Output $resp.Trim() }
