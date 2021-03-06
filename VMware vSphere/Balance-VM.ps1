# Connect to vCenter
Add-PSSnapin VMware.VimAutomation.Core -ErrorAction:SilentlyContinue
Connect-VIServer vcenter

# Cluster details
[string]$cluster = "Lab"
$hostinfo = Get-VMHost -Location (Get-Cluster $cluster) | Get-View

# Pull memory stats from each host
$hostram = @{}
$clusterram = 0
$hostinfo | % {
	$hostram.Add($_.Name,$_.Summary.QuickStats.OverallMemoryUsage)
	$clusterram += $_.Summary.QuickStats.OverallMemoryUsage
	}
$hostram.GetEnumerator() | Sort-Object Name

# Determine the delta on the least loaded host
$deltahost = ($hostram.GetEnumerator() | Sort-Object Value)[0].Name
$deltaram = [Math]::Round((($clusterram / $hostinfo.Count) - ($hostram.GetEnumerator() | Sort-Object Value)[0].Value),0)
$deltamoref = (Get-VMHost -Name $deltahost).Id
Write-Host "Let me try to remediate the imbalance on $deltahost"

# Find VMs that can fill the delta from other hosts
$vmram = @{}
Get-VM -Location (Get-Cluster $cluster) | Get-View | % {
	if ($_.Runtime.PowerState -match "poweredOn") {$vmram.Add($_.Name,$_.Summary.QuickStats.HostMemoryUsage)}
	}

# Run through VMs and migrate the smallest ones
$i = 0
$nomigration = $true
while ($nomigration) {
	$targetvm = ($vmram.GetEnumerator() | Sort-Object Value)[$i].Name
	if (((Get-VM -Name $targetvm | Get-View).Runtime.Host) -ne $deltamoref) {
		Write-Host "Moving $targetvm to $deltahost"
		Move-VM -VM (Get-VM -Name $targetvm) -Destination (Get-VMHost -Name $deltahost) -VMotionPriority:High | Out-Null
		$nomigration = $false
		}
	$i++
	
	#catch all
	if ($i -ge 100) {$nomigration = $false}
	}