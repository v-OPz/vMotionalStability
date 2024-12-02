function Get-ESXiHostUptime {
    <#
    .SYNOPSIS
    View ESXi host(s) uptime. Provide a single ESXi host name to view only that hosts uptime, negate ESXi host to view all ESXi hosts uptime in the provided cluster name.
    .EXAMPLE
    Get-ESXiHostUptime -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Get-ESXiHostUptime -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    if ($ESXiHostName) {
        Write-Output "Fetching uptime for $ESXiHostName"
        $singleESXiHost = Get-VMHost -Name $ESXiHostName
        $uptime = (Get-VMHostUptime -VMHost $singleESXiHost).Uptime
        Write-Output "$ESXiHostName has an uptime of $uptime"
    } else {
        $cluster = Get-Cluster -Name $ClusterName
        $ESXiHosts = Get-VMHost -Location $cluster

        foreach ($ESXiHost in $ESXiHosts) {
            Write-Output "Fetching uptime for $host"
            $uptime = (Get-VMHostUptime -VMHost $ESXiHost).Uptime
            Write-Output "$host has an uptime of $uptime"
        }
    }
}

function Get-ESXiVmkSettings {
    <#
    .SYNOPSIS
    Use this to view vmk settings on either 1 host or all hosts in the cluster
    .EXAMPLE
    Get-ESXiVmkSettings -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Get-ESXiVmkSettings -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    $report = @()

    if ($ESXiHostName) {
        $esxiHosts = @(Get-VMHost -Name $ESXiHostName)
    } else {
        $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
        $ESXiHosts = Get-VMHost -Location $cluster -ErrorAction SilentlyContinue
    }

    foreach ($ESXiHost in $ESXiHosts) {
        $currentESXiHost = $_
        Write-Host "Fetching VMkernel settings for $host"
        $vmkInfo = $ESXiHost | Get-VMHostNetworkAdapter -VMKernel
        foreach ($vmk in $vmkInfo) {
            $report += [PSCustomObject]@{
                HostName     = $currentESXiHost.Name
                VmkName      = $vmk.Name
                NetworkStack = $vmk.NetStackInstance
                IPAddress    = $vmk.IPv4Address
                MACAddress   = $vmk.MACAddress
                SubnetMask   = $vmk.IPv4Netmask
                VLANId       = $vmk.VlanId
                MTU          = $vmk.Mtu
                gateway      = $vmk.Gateway
            }
        }
    }

    $report | Format-Table -AutoSize
}

function Get-ESXiVmnicSettings {
    <#
    .SYNOPSIS
    Use this to view vmnic settings on either 1 host or all hosts in the cluster
    .EXAMPLE
    Get-ESXiVmnicSettings -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Get-ESXiVmnicSettings -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    $report = @()

    if ($ESXiHostName) {
        $esxiHosts = @(Get-VMHost -Name $ESXiHostName)
    } else {
        $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
        $ESXiHosts = Get-VMHost -Location $cluster -ErrorAction SilentlyContinue
    }

    foreach ($ESXiHost in $ESXiHosts) {
        $currentESXiHost = $_
        Write-Host "Fetching VMNIC settings for $host"
        $vmnicInfo = $currentESXiHost | Get-VMHostNetworkAdapter -Physical
        foreach ($vmnic in $vmnicInfo) {
            $report += [PSCustomObject]@{
                HostName    = $currentESXiHost.Name
                VmnicName   = $vmnic.Name
                AdminStatus = $vmnic.AdminStatus
                LinkStatus  = $vmnic.LinkStatus
                SpeedMb     = $vmnic.SpeedMb
                MACAddress  = $vmnic.Mac
                MTU         = $vmnic.Mtu
            }
        }
    }

    $report | Format-Table -AutoSize
}