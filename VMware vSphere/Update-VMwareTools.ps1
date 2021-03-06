Connect-VIServer -Credential (Get-Credential)

$datacenter = Read-Host "Datacenter: "
$cluster = Read-Host "Cluster: "
$folder = Read-Host "Folder: "

Get-VM -Location (Get-Datacenter $datacenter | Get-Cluster $cluster | Get-Folder $folder) | Update-Tools -NoReboot -RunAsync