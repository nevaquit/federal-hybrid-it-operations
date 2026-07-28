# Active Directory Health Assessment Toolkit

## Overview

`Invoke-ADHealthAssessment.ps1` is a read-only PowerShell assessment utility for validating core Active Directory operational health. It collects structured results, assigns Pass, Warning, Fail, or Info status, and generates both HTML and JSON reports.

## Portfolio Value

This artifact demonstrates senior infrastructure capabilities in:

- Active Directory health monitoring
- PowerShell automation and structured objects
- Replication and DNS troubleshooting
- FSMO role discovery
- Windows service and event-log analysis
- Executive and machine-readable reporting
- Remediation guidance and operational exit codes

## Requirements

- Windows PowerShell 5.1 or later
- Domain-joined Windows host
- Active Directory PowerShell module
- DNS Server tools for zone enumeration
- RSAT utilities, including `repadmin.exe`
- Permissions to query Active Directory, DNS, services, and event logs

## Usage

Run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Import-Module ActiveDirectory
.\Invoke-ADHealthAssessment.ps1
```

Specify a report directory and review window:

```powershell
.\Invoke-ADHealthAssessment.ps1 `
    -OutputDirectory C:\Evidence\ADHealth `
    -HoursBack 24
```

## Health Checks

The toolkit evaluates:

- Forest and domain identity
- Domain and forest functional levels
- Domain controller count
- NTDS, DNS, Netlogon, DFSR, and Windows Time services
- Replication summary and partner status
- DNS zones and domain-controller SRV records
- FSMO role holders
- Critical and error events in Directory Service, DNS Server, and System logs

See [Health-Checks.md](docs/Health-Checks.md) for technical detail and remediation guidance.

## Reports

The script generates:

- `ADHealthReport.html` for leadership review and visual triage
- `ADHealthReport.json` for dashboards, pipelines, and downstream automation

Sanitized examples are available in the [reports directory](reports/README.md).

## Exit Codes

| Code | Meaning |
|---:|---|
| `0` | No warnings or failures detected |
| `1` | One or more warnings detected |
| `2` | One or more failures detected |
| `3` | Assessment could not complete |

## Validation Procedure

1. Run the script after DC01 is deployed.
2. Confirm the HTML and JSON reports are created.
3. Compare replication results with `repadmin /replsummary` and `repadmin /showrepl`.
4. Compare domain health with `dcdiag`.
5. Verify DNS SRV resolution independently.
6. Introduce one controlled lab fault and confirm the report detects it.
7. Restore the service and confirm the next report returns to normal.

## Security Notes

- The script is designed to be read-only.
- No credentials are embedded or written to reports.
- Generated evidence may contain internal hostnames, domain names, event details, and topology information.
- Test in a non-production environment before enterprise adoption.

## Interview Talking Points

Be prepared to explain:

- Why DNS health is inseparable from Active Directory health
- How replication failures affect authentication and policy consistency
- Why JSON and HTML outputs serve different audiences
- How exit codes support scheduled tasks and monitoring systems
- Why automated checks still require validation against native tools

## Planned Enhancements

- Pester tests
- PSScriptAnalyzer enforcement
- LDAPS certificate checks
- SYSVOL backlog checks
- Time-source hierarchy validation
- Scheduled execution and notification
- GitHub Actions quality gates
