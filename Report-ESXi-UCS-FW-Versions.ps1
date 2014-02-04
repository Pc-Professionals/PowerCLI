# Script to report on running ESXi host UCS firmware versions.
#
# Assumptions:
#    1. You have already connected to the appropriate vSphere server and UCS environment in PowerShell/PowerCLI.
#    2. The path you enter for the -Path parameter is valid and you have the proper rights to write files there.
#
# Author: Tim Patterson <timothy.patterson@proquest.com>
# Last Updated: 2014-02-04
# 

[CmdletBinding()]
Param(
[Parameter(Mandatory=$True, HelpMessage="ESXi Cluster to Update")]
	[string]$ESXiCluster,
	
	[Parameter(Mandatory=$True, HelpMessage="ESXi Host(s) in cluster to update. Specify * for all hosts.")]
	[string]$ESXiHost,
	
	[Parameter(Mandatory=$True, HelpMessage="Exact path and filename to save CSV output to.")]
	[string]$path
)

try {
	$report = @()
	Foreach ($VMHost in (Get-Cluster $ESXiCluster | Get-VMHost | ? {$_.Name -like "$ESXiHost"})) {
		# Correlating ESXi host to UCS service profile:
		$vmMacAddr = $VMHost.NetworkInfo.PhysicalNic | where { $_.name -ieq "vmnic0" }
		$sp =  Get-UcsServiceProfile | Get-UcsVnic -Name eth0 |  where { $_.addr -ieq  $vmMacAddr.Mac } | Get-UcsParent 
		
		# Find the physical hardware the service profile is running on:
		$server = $sp.PnDn
		
		# Retrieve firmware information:
		$firmware = Get-UcsFirmwareRunning -Filter "dn -ilike $server*"
		$adapterfw = $firmware | ?{$_.Type -eq "adaptor" -and $_.Deployment -eq "system"} | Select-Object -ExpandProperty Version
		$cimcfw = $firmware | ?{$_.Type -eq "blade-controller" -and $_.Deployment -eq "system"} | Select-Object -ExpandProperty Version
		$biosfw = $firmware | ?{$_.Type -eq "blade-bios"} | Select-Object -ExpandProperty Version
		$boardcontrollerfw = $firmware | ?{$_.Type -eq "board-controller"} | Select-Object -ExpandProperty Version
		$spfwpolicy = $sp | Select-Object -ExpandProperty OperHostFwPolicyName
		
		$obj = New-Object -typename System.Object
		$obj | Add-Member -MemberType noteProperty -name ESXiHost -value $VMHost.Name
		$obj | Add-Member -MemberType noteProperty -name UCSserviceProfile -value $sp.Name
		$obj | Add-Member -MemberType noteProperty -name ServiceProfileFWPolicy -value $spfwpolicy
		$obj | Add-Member -MemberType noteProperty -name AdapterFW -value $adapterfw
		$obj | Add-Member -MemberType noteProperty -name CimcFW -value $cimcfw
		$obj | Add-Member -MemberType noteProperty -name BiosFW -value $biosfw
		$obj | Add-Member -MemberType noteProperty -name BoardControllerFW -value $boardcontrollerfw
		
		$obj
		$report += $obj
		$obj = $null
	}
	$report | Sort-Object UCSserviceProfile | Export-Csv -Path $path -NoTypeInformation
}
Catch 
{
	 Write-Host "Error occurred in script:"
	 Write-Host ${Error}
	 Write-Host "Finished process at $(date)"
         exit
}
Write-Host "Finished process at $(date)"
