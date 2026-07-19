#requires -Version 5.1
#requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Performs a read-only health assessment of an Active Directory environment.

.DESCRIPTION
    Collects domain controller reachability, core service status, SYSVOL and NETLOGON
    share availability, replication failures, DNS registration, time synchronization,
    and directory database free-space indicators. Results are written to the console
    and optionally exported as JSON and CSV evidence files.

.PARAMETER OutputPath
    Directory used for exported evidence. The directory is created when required.

.PARAMETER SkipDcDiag
    Skips DCDIAG execution when the utility is unavailable or intentionally excluded.

.EXAMPLE
    .\Test-ADHealth.ps1 -OutputPath C:\Evidence\AD-Health

.NOTES
    Author: Henry Jenkins
    Safety: Read-only. Test in a non-production environment before operational use.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath 'output'),

    [Parameter()]
    [switch]$SkipDcDiag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-HealthResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$DomainController,
        [Parameter(Mandatory)] [string]$Check,
        [Parameter(Mandatory)] [ValidateSet('Pass','Warning','Fail','Info')] [string]$Status,
        [Parameter(Mandatory)] [string]$Details
    )

    [pscustomobject]@{
        Timestamp        = (Get-Date).ToString('s')
        DomainController = $DomainController
        Check             = $Check
        Status            = $Status
        Details           = $Details
    }
}

function Test-RequiredCommand {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install the Active Directory tools and try again."
    }
}

Test-RequiredCommand -Name 'Get-ADDomain'
Test-RequiredCommand -Name 'Get-ADDomainController'

$null = New-Item -Path $OutputPath -ItemType Directory -Force
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$results = [System.Collections.Generic.List[object]]::new()

$domain = Get-ADDomain
$domainControllers = Get-ADDomainController -Filter * | Sort-Object HostName

foreach ($dc in $domainControllers) {
    $server = $dc.HostName

    try {
        $reachable = Test-Connection -ComputerName $server -Count 2 -Quiet
        $results.Add((New-HealthResult -DomainController $server -Check 'Network Reachability' -Status $(if ($reachable) {'Pass'} else {'Fail'}) -Details $(if ($reachable) {'ICMP response received.'} else {'No ICMP response received.'})))
    }
    catch {
        $results.Add((New-HealthResult -DomainController $server -Check 'Network Reachability' -Status 'Fail' -Details $_.Exception.Message))
    }

    foreach ($serviceName in 'NTDS','DNS','Netlogon','KDC','W32Time','DFSR') {
        try {
            $service = Get-Service -ComputerName $server -Name $serviceName -ErrorAction Stop
            $status = if ($service.Status -eq 'Running') { 'Pass' } else { 'Fail' }
            $results.Add((New-HealthResult -DomainController $server -Check "Service: $serviceName" -Status $status -Details "Service state: $($service.Status)."))
        }
        catch {
            $results.Add((New-HealthResult -DomainController $server -Check "Service: $serviceName" -Status 'Warning' -Details $_.Exception.Message))
        }
    }

    foreach ($shareName in 'SYSVOL','NETLOGON') {
        $sharePath = "\\$server\$shareName"
        try {
            $available = Test-Path -Path $sharePath
            $results.Add((New-HealthResult -DomainController $server -Check "Share: $shareName" -Status $(if ($available) {'Pass'} else {'Fail'}) -Details $(if ($available) {"$sharePath is available."} else {"$sharePath is unavailable."})))
        }
        catch {
            $results.Add((New-HealthResult -DomainController $server -Check "Share: $shareName" -Status 'Fail' -Details $_.Exception.Message))
        }
    }

    try {
        $dnsRecord = Resolve-DnsName -Name $server -Type A -ErrorAction Stop
        $addresses = ($dnsRecord | Where-Object IPAddress | Select-Object -ExpandProperty IPAddress) -join ', '
        $results.Add((New-HealthResult -DomainController $server -Check 'DNS Host Registration' -Status 'Pass' -Details "Resolved address(es): $addresses"))
    }
    catch {
        $results.Add((New-HealthResult -DomainController $server -Check 'DNS Host Registration' -Status 'Fail' -Details $_.Exception.Message))
    }

    try {
        $osDisk = Get-CimInstance -ComputerName $server -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freePercent = [math]::Round(($osDisk.FreeSpace / $osDisk.Size) * 100, 2)
        $diskStatus = if ($freePercent -ge 20) { 'Pass' } elseif ($freePercent -ge 10) { 'Warning' } else { 'Fail' }
        $results.Add((New-HealthResult -DomainController $server -Check 'System Drive Free Space' -Status $diskStatus -Details "$freePercent percent free on C:."))
    }
    catch {
        $results.Add((New-HealthResult -DomainController $server -Check 'System Drive Free Space' -Status 'Warning' -Details $_.Exception.Message))
    }

    try {
        $timeOutput = & w32tm.exe /query /computer:$server /status 2>&1
        $timeStatus = if ($LASTEXITCODE -eq 0) { 'Pass' } else { 'Warning' }
        $results.Add((New-HealthResult -DomainController $server -Check 'Time Synchronization' -Status $timeStatus -Details (($timeOutput | Out-String).Trim())))
    }
    catch {
        $results.Add((New-HealthResult -DomainController $server -Check 'Time Synchronization' -Status 'Warning' -Details $_.Exception.Message))
    }
}

try {
    $replicationFailures = Get-ADReplicationFailure -Target $domain.DNSRoot -Scope Domain
    if ($replicationFailures) {
        foreach ($failure in $replicationFailures) {
            $results.Add((New-HealthResult -DomainController $failure.Server -Check 'AD Replication' -Status 'Fail' -Details "Partner: $($failure.Partner); failures: $($failure.FailureCount); first failure: $($failure.FirstFailureTime)."))
        }
    }
    else {
        $results.Add((New-HealthResult -DomainController $domain.DNSRoot -Check 'AD Replication' -Status 'Pass' -Details 'No domain replication failures were returned.'))
    }
}
catch {
    $results.Add((New-HealthResult -DomainController $domain.DNSRoot -Check 'AD Replication' -Status 'Warning' -Details $_.Exception.Message))
}

if (-not $SkipDcDiag) {
    if (Get-Command -Name 'dcdiag.exe' -ErrorAction SilentlyContinue) {
        foreach ($dc in $domainControllers) {
            $dcDiagPath = Join-Path $OutputPath "dcdiag-$($dc.Name)-$timestamp.txt"
            & dcdiag.exe /s:$($dc.HostName) /q 2>&1 | Set-Content -Path $dcDiagPath -Encoding UTF8
            $dcDiagContent = Get-Content -Path $dcDiagPath -Raw
            $dcDiagStatus = if ([string]::IsNullOrWhiteSpace($dcDiagContent)) { 'Pass' } else { 'Warning' }
            $details = if ($dcDiagStatus -eq 'Pass') { 'DCDIAG quiet mode returned no errors.' } else { "Review evidence file: $dcDiagPath" }
            $results.Add((New-HealthResult -DomainController $dc.HostName -Check 'DCDIAG' -Status $dcDiagStatus -Details $details))
        }
    }
    else {
        $results.Add((New-HealthResult -DomainController $domain.DNSRoot -Check 'DCDIAG' -Status 'Info' -Details 'dcdiag.exe is not installed or not available in PATH.'))
    }
}

$csvPath = Join-Path $OutputPath "ad-health-$timestamp.csv"
$jsonPath = Join-Path $OutputPath "ad-health-$timestamp.json"

$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
$results | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding UTF8

$results | Sort-Object Status, DomainController, Check | Format-Table -AutoSize

$summary = $results | Group-Object Status | Sort-Object Name | Select-Object Name, Count
Write-Host "`nAssessment summary for $($domain.DNSRoot):"
$summary | Format-Table -AutoSize
Write-Host "CSV evidence:  $csvPath"
Write-Host "JSON evidence: $jsonPath"

if ($results.Status -contains 'Fail') {
    exit 2
}
elseif ($results.Status -contains 'Warning') {
    exit 1
}
else {
    exit 0
}
