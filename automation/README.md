# Automation Portfolio

This directory contains PowerShell automation designed to support enterprise infrastructure deployment, repeatable validation, evidence collection, and future monitoring integration.

## Featured Toolkits

### DC01 Deployment Automation

Location: [`DC01/`](DC01/README.md)

This package implements the current core-infrastructure milestone. It includes:

- Static IPv4 and DNS client configuration
- Server rename and Windows role installation
- New forest deployment for `corp.hjfb.lab`
- Secure runtime handling of the DSRM password
- DC01 deployment validation
- HTML and JSON evidence generation

Supporting material includes:

- [DC01 automation guide](DC01/README.md)
- [`Initialize-DC01.ps1`](DC01/Initialize-DC01.ps1)
- [`Deploy-HJFBForest.ps1`](DC01/Deploy-HJFBForest.ps1)
- [`Test-DC01Deployment.ps1`](DC01/Test-DC01Deployment.ps1)

### Active Directory Health Assessment

Location: [`ADHealthAssessment/`](ADHealthAssessment/README.md)

The toolkit provides a read-only operational assessment of Active Directory and produces both HTML and JSON reports. It evaluates:

- Forest and domain identity
- Functional levels
- Domain controller count
- NTDS, DNS, Netlogon, DFSR, and Windows Time services
- Replication with `repadmin`
- DNS zones and domain-controller SRV records
- FSMO role holders
- Directory Service, DNS Server, and System event logs

Supporting material includes:

- [Toolkit README](ADHealthAssessment/README.md)
- [Health-check catalog](ADHealthAssessment/docs/Health-Checks.md)
- [Sanitized report examples](ADHealthAssessment/reports/README.md)

## Legacy Baseline Script

`Test-ADHealth.ps1` is the earlier domain-controller-focused assessment. It remains useful as a comparison artifact and demonstrates the progression from a baseline operational script to a more complete reporting toolkit.

The baseline script checks:

- Domain controller reachability
- Active Directory, DNS, Netlogon, Kerberos, time, and DFS Replication services
- SYSVOL and NETLOGON shares
- DNS host registration
- System-drive free space
- Windows time synchronization
- Replication failures
- Optional DCDIAG results

## Engineering Standards

Automation in this portfolio should include:

- Comment-based help
- Parameter validation
- Structured PowerShell objects
- Clear error handling
- Read-only behavior unless modification is explicitly required
- `SupportsShouldProcess` and `-WhatIf` for high-impact changes
- Meaningful exit codes
- Human-readable and machine-readable reporting
- Security-conscious evidence handling
- Documented validation and rollback considerations

## Usage Principles

1. Test scripts in a non-production lab.
2. Review high-impact changes with `-WhatIf` before execution.
3. Validate results against native administrative tools.
4. Review generated evidence for sensitive information.
5. Apply peer review and change control before production adoption.
6. Record lessons learned and remediation outcomes.

## Current Automation Roadmap

| Artifact | Status |
|---|---|
| Active Directory baseline health script | Complete |
| Active Directory Health Assessment Toolkit | Complete, live validation pending |
| DC01 prerequisite automation | Complete, live execution pending |
| HJFB forest deployment automation | Complete, live execution pending |
| DC01 validation automation | Complete, live execution pending |
| Hyper-V host readiness toolkit | Planned |
| DHCP and DNS post-deployment automation | Next |
| Active Directory user provisioning module | Planned |
| Group Policy baseline validation | Planned |
| Windows Server health toolkit | Planned |
| GitHub Actions PowerShell quality gates | Future |

## Interview Talking Points

This automation portfolio demonstrates the ability to translate infrastructure operations into phased, repeatable engineering controls; protect secrets; support dry runs; produce audit-friendly evidence; separate deployment from validation; and design tools that can later integrate with scheduled tasks, monitoring platforms, and CI pipelines.
