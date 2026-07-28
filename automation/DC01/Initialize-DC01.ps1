<#
.SYNOPSIS
    Prepares a Windows Server virtual machine for promotion as DC01.
.DESCRIPTION
    Applies the lab static IPv4 configuration, configures DNS client settings,
    renames the server, installs AD DS, DNS, and DHCP roles, and records a JSON
    deployment summary. The script is designed for the isolated HJFB lab and
    supports -WhatIf through PowerShell ShouldProcess.
.PARAMETER InterfaceAlias
    Network adapter connected to the LAB-NAT virtual switch.
.PARAMETER ComputerName
    Required server name. Defaults to DC01.
.PARAMETER IPAddress
    Static IPv4 address assigned to DC01.
.PARAMETER PrefixLength
    IPv4 prefix length. Defaults to 24.
.PARAMETER DefaultGateway
    LAB-NAT gateway hosted by the Hyper-V host.
.PARAMETER DnsServers
    DNS client server addresses. DC01 initially points to its own static address.
.PARAMETER Restart
    Restarts the server when preparation is complete and a restart is required.
.EXAMPLE
    .\Initialize-DC01.ps1 -InterfaceAlias Ethernet -Restart -Confirm:$false
.NOTES
    Run locally from an elevated Windows PowerShell session on the DC01 virtual
    machine. Test only in a non-production lab.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$InterfaceAlias = 'Ethernet',

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9-]{1,15}$')]
    [string]$ComputerName = 'DC01',

    [Parameter()]
    [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]([System.Net.IPAddress]$null)) })]
    [string]$IPAddress = '10.20.0.10',

    [Parameter()]
    [ValidateRange(1, 32)]
    [int]$PrefixLength = 24,

    [Parameter()]
    [ValidateScript({ [System.Net.IPAddress]::TryParse($_, [ref]([System.Net.IPAddress]$null)) })]
    [string]$DefaultGateway = '10.20.0.1',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$DnsServers = @('10.20.0.10'),

    [Parameter()]
    [switch]$Restart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stateRoot = 'C:\ProgramData\HJFB-Lab'
$logRoot = Join-Path $stateRoot 'Logs'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = Join-Path $logRoot "Initialize-DC01-$timestamp.log"
$summaryPath = Join-Path $logRoot "Initialize-DC01-$timestamp.json"
$transcriptStarted = $false
$restartRequired = $false

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IPv4Address {
    param([Parameter(Mandatory)][string]$Address)

    $parsed = $null
    return [System.Net.IPAddress]::TryParse($Address, [ref]$parsed) -and
        $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
}

try {
    if (-not (Test-IsAdministrator)) {
        throw 'This script must be run from an elevated PowerShell session.'
    }

    foreach ($address in @($IPAddress, $DefaultGateway) + $DnsServers) {
        if (-not (Test-IPv4Address -Address $address)) {
            throw "Invalid IPv4 address supplied: $address"
        }
    }

    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    $transcriptStarted = $true

    $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
    if ($adapter.Status -ne 'Up') {
        throw "Network adapter '$InterfaceAlias' is not in an Up state."
    }

    if ($PSCmdlet.ShouldProcess($InterfaceAlias, 'Disable IPv4 DHCP and configure a static address')) {
        Set-NetIPInterface -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Dhcp Disabled

        $existingAddresses = @(Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.IPAddress -ne $IPAddress -and
                $_.IPAddress -notlike '169.254.*' -and
                $_.PrefixOrigin -ne 'WellKnown'
            })

        foreach ($existingAddress in $existingAddresses) {
            Remove-NetIPAddress -InputObject $existingAddress -Confirm:$false
        }

        $targetAddress = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -IPAddress $IPAddress -ErrorAction SilentlyContinue
        if (-not $targetAddress) {
            New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength | Out-Null
        }

        $defaultRoutes = @(Get-NetRoute -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
        foreach ($route in $defaultRoutes | Where-Object NextHop -ne $DefaultGateway) {
            Remove-NetRoute -InputObject $route -Confirm:$false
        }

        if (-not (Get-NetRoute -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Where-Object NextHop -eq $DefaultGateway)) {
            New-NetRoute -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -NextHop $DefaultGateway | Out-Null
        }

        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServers
    }

    if ($env:COMPUTERNAME -ne $ComputerName) {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename computer to $ComputerName")) {
            Rename-Computer -NewName $ComputerName -Force
            $restartRequired = $true
        }
    }

    if ($PSCmdlet.ShouldProcess($ComputerName, 'Install AD DS, DNS, DHCP, and management tools')) {
        $featureResult = Install-WindowsFeature -Name AD-Domain-Services, DNS, DHCP -IncludeManagementTools
        if (-not $featureResult.Success) {
            throw 'One or more required Windows Server roles failed to install.'
        }

        if ([string]$featureResult.RestartNeeded -eq 'Yes') {
            $restartRequired = $true
        }
    }

    $summary = [pscustomobject]@{
        Stage            = 'DC01 prerequisite preparation'
        GeneratedAt      = (Get-Date).ToString('o')
        CurrentName      = $env:COMPUTERNAME
        RequestedName    = $ComputerName
        InterfaceAlias   = $InterfaceAlias
        IPAddress        = $IPAddress
        PrefixLength     = $PrefixLength
        DefaultGateway   = $DefaultGateway
        DnsServers       = $DnsServers
        RolesRequested   = @('AD-Domain-Services', 'DNS', 'DHCP')
        RestartRequired  = $restartRequired
        NextStep         = 'Run Deploy-HJFBForest.ps1 after any required restart.'
    }

    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    Write-Host 'DC01 prerequisite preparation completed.'
    Write-Host "Transcript: $transcriptPath"
    Write-Host "Summary:    $summaryPath"

    if ($restartRequired -and $Restart) {
        if ($transcriptStarted) {
            Stop-Transcript | Out-Null
            $transcriptStarted = $false
        }

        if ($PSCmdlet.ShouldProcess($ComputerName, 'Restart computer')) {
            Restart-Computer -Force
        }
    }
    elseif ($restartRequired) {
        Write-Warning 'A restart is required before forest deployment.'
    }
}
catch {
    Write-Error "DC01 preparation failed: $($_.Exception.Message)"
    exit 2
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
