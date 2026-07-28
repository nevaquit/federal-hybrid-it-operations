<#
.SYNOPSIS
    Validates the completed DC01 deployment.
.DESCRIPTION
    Performs read-only checks for domain identity, required services, SYSVOL and
    NETLOGON shares, FSMO roles, DNS resolution, replication tooling, and core
    diagnostics. Results are written to JSON and HTML for portfolio evidence.
.PARAMETER OutputDirectory
    Destination for validation reports.
.EXAMPLE
    .\Test-DC01Deployment.ps1 -OutputDirectory C:\Evidence\DC01
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'reports')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ValidationResult {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('Pass','Warning','Fail','Info')][string]$Status,
        [Parameter(Mandatory)][string]$Details,
        [string]$Recommendation = ''
    )

    [pscustomobject]@{
        Check          = $Check
        Status         = $Status
        Details        = $Details
        Recommendation = $Recommendation
    }
}

function Invoke-NativeCheck {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = & $Command @Arguments 2>&1 | Out-String
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = $output.Trim()
    }
}

try {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Import-Module ActiveDirectory -ErrorAction Stop

    $results = [System.Collections.Generic.List[object]]::new()
    $domain = Get-ADDomain
    $forest = Get-ADForest
    $dc = Get-ADDomainController -Identity $env:COMPUTERNAME

    $results.Add((New-ValidationResult -Check 'Computer Name' -Status $(if ($env:COMPUTERNAME -eq 'DC01') {'Pass'} else {'Fail'}) -Details $env:COMPUTERNAME -Recommendation 'Rename the server to DC01 before treating the build as complete.'))
    $results.Add((New-ValidationResult -Check 'Domain Name' -Status $(if ($domain.DNSRoot -eq 'corp.hjfb.lab') {'Pass'} else {'Fail'}) -Details $domain.DNSRoot -Recommendation 'Confirm the intended forest was deployed.'))
    $results.Add((New-ValidationResult -Check 'Forest Root Domain' -Status 'Info' -Details $forest.RootDomain))
    $results.Add((New-ValidationResult -Check 'Global Catalog' -Status $(if ($dc.IsGlobalCatalog) {'Pass'} else {'Fail'}) -Details ([string]$dc.IsGlobalCatalog) -Recommendation 'Enable Global Catalog on DC01.'))

    foreach ($serviceName in @('NTDS','DNS','Netlogon','DFSR','W32Time','DHCPServer')) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            $status = if ($service.Status -eq 'Running') {'Pass'} else {'Fail'}
            $results.Add((New-ValidationResult -Check "Service: $serviceName" -Status $status -Details ([string]$service.Status) -Recommendation "Start and troubleshoot the $serviceName service."))
        }
        catch {
            $results.Add((New-ValidationResult -Check "Service: $serviceName" -Status 'Warning' -Details $_.Exception.Message -Recommendation 'Confirm the corresponding server role is installed.'))
        }
    }

    foreach ($shareName in @('SYSVOL','NETLOGON')) {
        $share = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        $results.Add((New-ValidationResult -Check "Share: $shareName" -Status $(if ($share) {'Pass'} else {'Fail'}) -Details $(if ($share) {$share.Path} else {'Not found'}) -Recommendation 'Review DFS Replication and Netlogon events if the share is absent.'))
    }

    try {
        $srvRecords = @(Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$($forest.RootDomain)" -Type SRV -ErrorAction Stop)
        $results.Add((New-ValidationResult -Check 'LDAP SRV Records' -Status 'Pass' -Details "$($srvRecords.Count) response(s) returned."))
    }
    catch {
        $results.Add((New-ValidationResult -Check 'LDAP SRV Records' -Status 'Fail' -Details $_.Exception.Message -Recommendation 'Verify DNS zone health and force Netlogon registration.'))
    }

    $fsmoDetails = "Schema=$($forest.SchemaMaster); DomainNaming=$($forest.DomainNamingMaster); RID=$($domain.RIDMaster); PDC=$($domain.PDCEmulator); Infrastructure=$($domain.InfrastructureMaster)"
    $results.Add((New-ValidationResult -Check 'FSMO Role Holders' -Status 'Info' -Details $fsmoDetails))

    if (Get-Command dcdiag.exe -ErrorAction SilentlyContinue) {
        $dcdiag = Invoke-NativeCheck -Command 'dcdiag.exe' -Arguments @('/q')
        $results.Add((New-ValidationResult -Check 'DCDIAG Quick Validation' -Status $(if ($dcdiag.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($dcdiag.Output)) {'Pass'} else {'Fail'}) -Details $(if ($dcdiag.Output) {$dcdiag.Output} else {'No errors returned.'}) -Recommendation 'Run dcdiag /v and investigate failed tests.'))
    }

    if (Get-Command repadmin.exe -ErrorAction SilentlyContinue) {
        $repadmin = Invoke-NativeCheck -Command 'repadmin.exe' -Arguments @('/replsummary')
        $results.Add((New-ValidationResult -Check 'Replication Summary' -Status $(if ($repadmin.ExitCode -eq 0 -and $repadmin.Output -notmatch '(?i)error|failed') {'Pass'} else {'Warning'}) -Details $repadmin.Output -Recommendation 'A single-DC lab has no replication partner; re-run after DC02 is deployed.'))
    }

    $failures = @($results | Where-Object Status -eq 'Fail').Count
    $warnings = @($results | Where-Object Status -eq 'Warning').Count
    $overall = if ($failures -gt 0) {'Fail'} elseif ($warnings -gt 0) {'Warning'} else {'Pass'}

    $report = [pscustomobject]@{
        Assessment   = 'DC01 Deployment Validation'
        GeneratedAt  = (Get-Date).ToString('o')
        ComputerName = $env:COMPUTERNAME
        Domain       = $domain.DNSRoot
        Overall      = $overall
        Failures     = $failures
        Warnings     = $warnings
        Results      = $results
    }

    $jsonPath = Join-Path $OutputDirectory 'DC01-Validation.json'
    $htmlPath = Join-Path $OutputDirectory 'DC01-Validation.html'
    $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $rows = foreach ($item in $results) {
        "<tr class='$($item.Status)'><td>$($item.Check)</td><td>$($item.Status)</td><td>$([System.Net.WebUtility]::HtmlEncode($item.Details))</td><td>$([System.Net.WebUtility]::HtmlEncode($item.Recommendation))</td></tr>"
    }

    $html = @"
<!DOCTYPE html>
<html><head><meta charset='utf-8'><title>DC01 Validation</title>
<style>body{font-family:Segoe UI,Arial;margin:28px;background:#f4f6f8;color:#1f2937}table{border-collapse:collapse;width:100%;background:white}th,td{padding:9px;border:1px solid #d1d5db;text-align:left;vertical-align:top}th{background:#17365d;color:white}.Pass{background:#dcfce7}.Warning{background:#fef3c7}.Fail{background:#fee2e2}.Info{background:#dbeafe}</style>
</head><body><h1>DC01 Deployment Validation</h1><p><strong>Overall:</strong> $overall | Failures: $failures | Warnings: $warnings</p><p><strong>Domain:</strong> $($domain.DNSRoot)</p><table><thead><tr><th>Check</th><th>Status</th><th>Details</th><th>Recommendation</th></tr></thead><tbody>$($rows -join [Environment]::NewLine)</tbody></table></body></html>
"@
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

    Write-Host "Validation complete: $overall"
    Write-Host "HTML: $htmlPath"
    Write-Host "JSON: $jsonPath"

    if ($overall -eq 'Fail') { exit 2 }
    if ($overall -eq 'Warning') { exit 1 }
    exit 0
}
catch {
    Write-Error "DC01 validation failed: $($_.Exception.Message)"
    exit 3
}
