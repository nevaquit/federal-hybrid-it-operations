<#
.SYNOPSIS
    Performs a baseline Active Directory health assessment.
.DESCRIPTION
    Collects domain, forest, service, replication, DNS, FSMO, and event-log data.
    Generates both HTML and JSON reports for operational review and portfolio evidence.
.PARAMETER OutputDirectory
    Directory where the reports will be written.
.PARAMETER HoursBack
    Number of hours of event-log history to review.
.EXAMPLE
    .\Invoke-ADHealthAssessment.ps1 -OutputDirectory .\reports -HoursBack 24
.NOTES
    Run from an elevated PowerShell session on a domain-joined management host with
    the ActiveDirectory module and RSAT tools installed.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'reports'),

    [Parameter()]
    [ValidateRange(1,168)]
    [int]$HoursBack = 24
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-HealthResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('Pass','Warning','Fail','Info')][string]$Status,
        [Parameter(Mandatory)][string]$Details,
        [string]$Recommendation = ''
    )

    [pscustomobject]@{
        Category       = $Category
        Check          = $Check
        Status         = $Status
        Details        = $Details
        Recommendation = $Recommendation
    }
}

function Test-RequiredCommand {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-ExternalCheck {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & $FilePath @Arguments 2>&1 | Out-String
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = $output.Trim()
    }
}

function Get-ServiceHealth {
    param([Parameter(Mandatory)][string[]]$Names)

    foreach ($name in $Names) {
        try {
            $service = Get-Service -Name $name -ErrorAction Stop
            $status = if ($service.Status -eq 'Running') { 'Pass' } else { 'Fail' }
            $recommendation = if ($status -eq 'Fail') { "Start the $name service and investigate dependent-service or event-log errors." } else { '' }
            New-HealthResult -Category 'Services' -Check $name -Status $status -Details "Service status: $($service.Status)" -Recommendation $recommendation
        }
        catch {
            New-HealthResult -Category 'Services' -Check $name -Status 'Warning' -Details "Service not found or unavailable: $($_.Exception.Message)" -Recommendation 'Confirm the expected server role is installed on this host.'
        }
    }
}

function Get-EventLogHealth {
    param(
        [Parameter(Mandatory)][string[]]$LogNames,
        [Parameter(Mandatory)][datetime]$StartTime
    )

    foreach ($logName in $LogNames) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName = $logName; Level = 1,2; StartTime = $StartTime } -ErrorAction Stop
            $count = @($events).Count
            $status = if ($count -eq 0) { 'Pass' } elseif ($count -le 5) { 'Warning' } else { 'Fail' }
            $details = if ($count -eq 0) { 'No critical or error events detected.' } else { "$count critical/error event(s) detected during the review window." }
            $recommendation = if ($count -gt 0) { "Review the newest events in the $logName log and correlate them with replication, DNS, or service findings." } else { '' }
            New-HealthResult -Category 'Event Logs' -Check $logName -Status $status -Details $details -Recommendation $recommendation
        }
        catch {
            New-HealthResult -Category 'Event Logs' -Check $logName -Status 'Warning' -Details "Unable to query log: $($_.Exception.Message)" -Recommendation 'Confirm the log exists and that the account has permission to read it.'
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    Import-Module ActiveDirectory -ErrorAction Stop
    $results = [System.Collections.Generic.List[object]]::new()
    $timestamp = Get-Date
    $startTime = $timestamp.AddHours(-$HoursBack)

    $forest = Get-ADForest
    $domain = Get-ADDomain
    $domainControllers = @(Get-ADDomainController -Filter *)

    $results.Add((New-HealthResult -Category 'Directory' -Check 'Forest' -Status 'Info' -Details $forest.Name))
    $results.Add((New-HealthResult -Category 'Directory' -Check 'Domain' -Status 'Info' -Details $domain.DNSRoot))
    $results.Add((New-HealthResult -Category 'Directory' -Check 'Forest Functional Level' -Status 'Info' -Details ([string]$forest.ForestMode)))
    $results.Add((New-HealthResult -Category 'Directory' -Check 'Domain Functional Level' -Status 'Info' -Details ([string]$domain.DomainMode)))
    $dcStatus = if ($domainControllers.Count -ge 2) { 'Pass' } else { 'Warning' }
    $dcRecommendation = if ($domainControllers.Count -lt 2) { 'Deploy a second domain controller to improve resiliency and maintenance flexibility.' } else { '' }
    $results.Add((New-HealthResult -Category 'Directory' -Check 'Domain Controller Count' -Status $dcStatus -Details ([string]$domainControllers.Count) -Recommendation $dcRecommendation))

    foreach ($result in Get-ServiceHealth -Names @('NTDS','DNS','Netlogon','DFSR','W32Time')) {
        $results.Add($result)
    }

    if (Test-RequiredCommand -Name 'repadmin.exe') {
        $repSummary = Invoke-ExternalCheck -FilePath 'repadmin.exe' -Arguments @('/replsummary')
        $repStatus = if ($repSummary.ExitCode -eq 0 -and $repSummary.Output -notmatch '(?i)failures|error') { 'Pass' } else { 'Fail' }
        $repRecommendation = if ($repStatus -eq 'Fail') { 'Run repadmin /showrepl, verify DNS resolution and network connectivity, and investigate replication event logs.' } else { '' }
        $results.Add((New-HealthResult -Category 'Replication' -Check 'repadmin /replsummary' -Status $repStatus -Details $repSummary.Output -Recommendation $repRecommendation))

        $showRepl = Invoke-ExternalCheck -FilePath 'repadmin.exe' -Arguments @('/showrepl')
        $showStatus = if ($showRepl.ExitCode -eq 0 -and $showRepl.Output -notmatch '(?i)last error|failed') { 'Pass' } else { 'Warning' }
        $results.Add((New-HealthResult -Category 'Replication' -Check 'repadmin /showrepl' -Status $showStatus -Details $showRepl.Output -Recommendation 'Review any partner-specific errors and validate site, subnet, DNS, and firewall configuration.'))
    }
    else {
        $results.Add((New-HealthResult -Category 'Replication' -Check 'Repadmin Availability' -Status 'Warning' -Details 'repadmin.exe was not found.' -Recommendation 'Install the Active Directory Domain Services RSAT tools.'))
    }

    try {
        $zones = @(Get-DnsServerZone -ErrorAction Stop)
        $zoneStatus = if ($zones.Count -gt 0) { 'Pass' } else { 'Fail' }
        $results.Add((New-HealthResult -Category 'DNS' -Check 'DNS Zones' -Status $zoneStatus -Details (($zones.ZoneName | Sort-Object) -join ', ') -Recommendation 'Confirm AD-integrated forward and reverse lookup zones exist and are healthy.'))
    }
    catch {
        $results.Add((New-HealthResult -Category 'DNS' -Check 'DNS Zones' -Status 'Warning' -Details "Unable to enumerate zones: $($_.Exception.Message)" -Recommendation 'Run the assessment on a DNS server or install the DNS Server tools.'))
    }

    try {
        $srvRecords = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$($forest.RootDomain)" -Type SRV -ErrorAction Stop
        $results.Add((New-HealthResult -Category 'DNS' -Check 'Domain Controller SRV Records' -Status 'Pass' -Details "$(@($srvRecords).Count) LDAP SRV record response(s) returned."))
    }
    catch {
        $results.Add((New-HealthResult -Category 'DNS' -Check 'Domain Controller SRV Records' -Status 'Fail' -Details $_.Exception.Message -Recommendation 'Verify Netlogon registration, DNS zone health, and domain controller DNS client settings.'))
    }

    $fsmo = [ordered]@{
        SchemaMaster         = $forest.SchemaMaster
        DomainNamingMaster   = $forest.DomainNamingMaster
        RIDMaster            = $domain.RIDMaster
        PDCEmulator          = $domain.PDCEmulator
        InfrastructureMaster = $domain.InfrastructureMaster
    }

    foreach ($role in $fsmo.GetEnumerator()) {
        $results.Add((New-HealthResult -Category 'FSMO' -Check $role.Key -Status 'Info' -Details ([string]$role.Value)))
    }

    foreach ($result in Get-EventLogHealth -LogNames @('Directory Service','DNS Server','System') -StartTime $startTime) {
        $results.Add($result)
    }

    $failCount = @($results | Where-Object Status -eq 'Fail').Count
    $warningCount = @($results | Where-Object Status -eq 'Warning').Count
    $overallStatus = if ($failCount -gt 0) { 'Fail' } elseif ($warningCount -gt 0) { 'Warning' } else { 'Pass' }

    $report = [pscustomobject]@{
        AssessmentName = 'Active Directory Health Assessment'
        GeneratedAt    = $timestamp.ToString('o')
        ComputerName   = $env:COMPUTERNAME
        Forest         = $forest.Name
        Domain         = $domain.DNSRoot
        OverallStatus  = $overallStatus
        Failures       = $failCount
        Warnings       = $warningCount
        Results        = $results
    }

    $jsonPath = Join-Path $OutputDirectory 'ADHealthReport.json'
    $htmlPath = Join-Path $OutputDirectory 'ADHealthReport.html'
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $style = @'
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:28px;background:#f5f7fa;color:#1f2937}
h1,h2{color:#17365d}.summary{background:white;padding:18px;border-radius:8px;margin-bottom:18px}
table{border-collapse:collapse;width:100%;background:white}th,td{border:1px solid #d1d5db;padding:9px;text-align:left;vertical-align:top}th{background:#17365d;color:white}
.Pass{background:#dcfce7}.Warning{background:#fef3c7}.Fail{background:#fee2e2}.Info{background:#dbeafe}
pre{white-space:pre-wrap;margin:0;font-family:Consolas,monospace;font-size:12px}
</style>
'@

    $summaryHtml = "<div class='summary'><h1>Active Directory Health Assessment</h1><p><strong>Generated:</strong> $timestamp</p><p><strong>Computer:</strong> $env:COMPUTERNAME</p><p><strong>Forest:</strong> $($forest.Name)</p><p><strong>Domain:</strong> $($domain.DNSRoot)</p><p><strong>Overall status:</strong> $overallStatus | Failures: $failCount | Warnings: $warningCount</p></div>"
    $rows = foreach ($item in $results) {
        $details = [System.Net.WebUtility]::HtmlEncode([string]$item.Details)
        $recommendation = [System.Net.WebUtility]::HtmlEncode([string]$item.Recommendation)
        "<tr class='$($item.Status)'><td>$($item.Category)</td><td>$($item.Check)</td><td>$($item.Status)</td><td><pre>$details</pre></td><td>$recommendation</td></tr>"
    }
    $table = "<table><thead><tr><th>Category</th><th>Check</th><th>Status</th><th>Details</th><th>Recommendation</th></tr></thead><tbody>$($rows -join [Environment]::NewLine)</tbody></table>"
    Set-Content -LiteralPath $htmlPath -Encoding UTF8 -Value "<!DOCTYPE html><html><head><meta charset='utf-8'><title>AD Health Report</title>$style</head><body>$summaryHtml$table</body></html>"

    Write-Host "Assessment complete. Overall status: $overallStatus"
    Write-Host "HTML report: $htmlPath"
    Write-Host "JSON report: $jsonPath"

    if ($overallStatus -eq 'Fail') { exit 2 }
    if ($overallStatus -eq 'Warning') { exit 1 }
    exit 0
}
catch {
    Write-Error "Active Directory health assessment failed: $($_.Exception.Message)"
    exit 3
}
