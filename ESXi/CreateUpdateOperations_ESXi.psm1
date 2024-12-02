using ..\Helpers\re-usables.psm1

function Set-ESXiNTPEndpoint {
    <#
    .SYNOPSIS
    Use this to set NTP server on all ESXi hosts in a cluster, function call includes a mandatory parameter for the cluster name.
    .EXAMPLE
    Set-ESXiNTPEndpoint -PrimaryNTPServer "pool.ntp.org" -SecondaryNTPServer "time.google.com" -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$PrimaryNTPServer,
        [string]$SecondaryNTPServer,
        [Parameter(Mandatory=$true)]
        [string]$ClusterName
    )

    $ntpServers = @($PrimaryNTPServer)
    if ($SecondaryNTPServer) {
        $ntpServers += $SecondaryNTPServer
    }

    foreach ($ntpServer in $ntpServers) {
        if (-not (Test-Server -NTPServer $ntpServer)) {
            Write-Output "Skipping NTP server: $ntpServer due to connectivity issues." -ForegroundColor Yellow
            $ntpServers = $ntpServers | Where-Object { $_ -ne $ntpServer }
        }
    }

    $cluster = Get-Cluster -Name $ClusterName
    $ESXiHosts = Get-VMHost -Location $cluster

    foreach ($ESXiHost in $ESXiHosts) {
        Write-Output "Setting NTP server(s) on $host"
        $esxcli = Get-EsxCli -VMHost $ESXiHost -V2
        $esxcli.system.ntp.set($null, $ntpServers -join ",")
        $esxcli.system.ntp.start()
        Write-Output "NTP server(s) set on $host"
    }
}

function Set-ESXiDNSEndpoint {
    <#
    .SYNOPSIS
    Use this to set DNS server on all ESXi hosts in a cluster, function call includes a mandatory parameter for the cluster name.
    .EXAMPLE
    Set-ESXiDNSEndpoint -PrimaryDNSServer "8.8.8.8" -SecondaryDNSServer "8.8.4.4" -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$PrimaryDNSServer,
        [string]$SecondaryDNSServer,
        [Parameter(Mandatory=$true)]
        [string]$ClusterName
    )

    $dnsServers = @($PrimaryDNSServer)
    if ($SecondaryDNSServer) {
        $dnsServers += $SecondaryDNSServer
    }

    foreach ($dnsServer in $dnsServers) {
        if (-not (Test-Server -DNSServer $dnsServer)) {
            Write-Host "Skipping DNS server: $dnsServer due to connectivity issues." -ForegroundColor Yellow
            $dnsServers = $dnsServers | Where-Object { $_ -ne $dnsServer }
        }
    }

    $cluster = Get-Cluster -Name $ClusterName
    $ESXiHosts = Get-VMHost -Location $cluster

    foreach ($ESXiHost in $ESXiHosts) {
        Write-Output "Setting DNS server(s) on $host"
        $esxcli = Get-EsxCli -VMHost $ESXiHost -V2
        $esxcli.network.ip.dns.server.add($null, $dnsServers -join ",")
        Write-Output "DNS server(s) set on $host"
    }
}

function Enable-ESXiSSH {
    <#
    .SYNOPSIS
    Use this to enable SSH on all ESXi hosts in a cluster
    .EXAMPLE
    Enable-SSH -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName
    )

    $cluster = Get-Cluster -Name $ClusterName
    $ESXiHosts = Get-VMHost -Location $cluster

    foreach ($ESXiHost in $ESXiHosts) {
        $ESXiHost | Get-VMHostService | Where-Object {$_.Key -eq "TSM-SSH"} | Start-VMHostService -Confirm:$false
        Write-Output "SSH enabled on $host"
    }
}

function Disable-ESXiSSH {
    <#
    .SYNOPSIS
    Use this to disable SSH on all ESXi hosts in a cluster
    .EXAMPLE
    Disable-SSH -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName
    )

    $cluster = Get-Cluster -Name $ClusterName
    $ESXiHosts = Get-VMHost -Location $cluster

    foreach ($ESXiHost in $ESXiHosts) {
        $ESXiHost | Get-VMHostService | Where-Object {$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false
        Write-Output "SSH disabled on $host"
    }
}

function Set-ESXiSyslogEndpoint {
    <#
    .SYNOPSIS
    Use this to set(define) the syslog server on all ESXi hosts in a cluster
    .EXAMPLE
    Set-ESXiSyslogEndpoint -SyslogServer "syslog.example.com" -ClusterName
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$SyslogServer,
        [Parameter(Mandatory=$true)]
        [string]$ClusterName
    )

    $cluster = Get-Cluster -Name $ClusterName
    $esxiHosts = Get-VMHost -Location $cluster

    foreach ($host in $esxiHosts) {
        $esxcli = Get-EsxCli -VMHost $host
        $esxcli.system.syslog.config.set($null, $SyslogServer)
        Write-Output "Syslog server set on $host"
    }
}

function Set-ESXiAdvancedSetting {
    <#
    .SYNOPSIS
    Use this to set(or unset) an advanced setting on ESXi host(s). You can provide a single ESXi host to target only that host.
    .EXAMPLE
    Set-ESXiAdvancedSetting -SettingName "UserVars.SuppressShellWarning" -SettingValue "1" -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Set-ESXiAdvancedSetting -SettingName "UserVars.SuppressShellWarning" -SettingValue "1" -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$SettingName,
        [Parameter(Mandatory=$true)]
        [string]$SettingValue,
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    if ($ESXiHostName) {
        $ESXiHost = Get-VMHost -Name $ESXiHostName
        $advancedSetting = Get-AdvancedSetting -Entity $ESXiHost | Where-Object {$_.Name -eq $SettingName}
         if($advancedSetting) {
            $esxcli = Get-EsxCli -VMHost $ESXiHost
            $esxcli.system.settings.advanced.set($null, $SettingName, $SettingValue)
            Write-Output "Advanced setting $SettingName set to $SettingValue on $ESXiHost"
        } else {
            Write-Output "Setting $SettingName does not exist on $ESXiHost, ending." -ForegroundColor Yellow
        }
    } else {
        $cluster = Get-Cluster -Name $ClusterName
        $ESXiHosts = Get-VMHost -Location $cluster
        $advancedSetting = Get-AdvancedSetting -Entity $ESXiHosts[0] | Where-Object {$_.Name -eq $SettingName}

        if($advancedSetting) {
            foreach ($ESXiHost in $esxiHosts) {
                $esxcli = Get-EsxCli -VMHost $ESXiHost
                $esxcli.system.settings.advanced.set($null, $SettingName, $SettingValue)
                Write-Output "Advanced setting $SettingName set to $SettingValue on $ESXiHost"
            }
        } else{Write-Output "Advanced setting not found."}
    }
}

function Enable-ESXiLockdownMode {
    <#
    .SYNOPSIS
    Use this to enable lockdown mode on either 1 host or all hosts in the cluster
    .EXAMPLE
    Enable-ESXiLockdownMode -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Enable-ESXiLockdownMode -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    if ($ESXiHostName) {
        Write-Output "Enabling lockdown mode on $ESXiHostName"
        $ESXiHost = Get-VMHost -Name $ESXiHostName
        $ESXiHost | Set-VMHost -Lockdown -Confirm:$false
        Write-Output "Lockdown mode enabled on $ESXiHostName"
    } else {
        $cluster = Get-Cluster -Name $ClusterName
        $ESXiHosts = Get-VMHost -Location $cluster

        foreach ($ESXiHost in $ESXiHosts) {
            Write-Output "Enabling lockdown mode on $host"
            $host | Set-VMHost -Lockdown -Confirm:$false
            Write-Output "Lockdown mode enabled on $host"
        }
    }
}

function Disable-ESXiLockdownMode {
    <#
    .SYNOPSIS
    Use this to disable lockdown mode on either 1 host or all hosts in the cluster
    .EXAMPLE
    Disable-ESXiLockdownMode -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Disable-ESXiLockdownMode -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    if ($ESXiHostName) {
        Write-Host "Disabling lockdown mode on $ESXiHostName"
        $ESXiHost = Get-VMHost -Name $ESXiHostName
        $ESXiHost | Set-VMHost -LockdownMode 'Disabled' -Confirm:$false
        Write-Host "Lockdown mode disabled on $ESXiHostName"
    } else {
        $cluster = Get-Cluster -Name $ClusterName
        $ESXiHosts = Get-VMHost -Location $cluster

        foreach ($ESXiHost in $ESXiHosts) {
            Write-Host "Disabling lockdown mode on $host"
            $host | Set-VMHost -LockdownMode 'Disabled' -Confirm:$false
            Write-Host "Lockdown mode disabled on $host"
        }
    }
}

function Restart-ESXiHost {
    <#
    .SYNOPSIS
    Restart an ESXi host that is already in Maintenance Mode 
    .EXAMPLE
    Restart-ESXiHost -ClusterName "Cluster1" -ESXiHostName "esx1.local"
    Restart-ESXiHost -ClusterName "Cluster1"
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ClusterName,
        [string]$ESXiHostName
    )

    $messages = @()

    if ($ESXiHostName) {
        $currentESXiHost = Get-VMHost -Name $ESXiHostName
        if ($currentESXiHost.ConnectionState -eq "Maintenance") {
            $messages += "Restarting $ESXiHostName"
            Restart-VMHost -VMHost $currentESXiHost -Confirm:$false
            $messages += "$ESXiHostName has been restarted"
        } else {
            $messages += "$ESXiHostName is not in Maintenance Mode. Please enter Maintenance Mode before restarting."
        }
    } else {
        $cluster = Get-Cluster -Name $ClusterName
        $esxiHosts = Get-VMHost -Location $cluster

        foreach ($ESXiHost in $esxiHosts) {
            if ($currentESXiHost.ConnectionState -eq "Maintenance") {
                $messages += "Restarting $host"
                Restart-VMHost -VMHost $currentESXiHost -Confirm:$false
                $messages += "$host has been restarted"
            } else {
                $messages += "$host is not in Maintenance Mode. Please enter Maintenance Mode before restarting."
            }
        }
    }

    $messages | Write-Output
}