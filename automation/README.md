# Automation Portfolio

This directory contains PowerShell automation designed to support enterprise infrastructure operations, repeatable validation, evidence collection, and future monitoring integration.

## Featured Toolkit

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
- Meaningful exit codes
- Human-readable and machine-readable reporting
- Security-conscious evidence handling
- Documented validation and rollback considerations

## Usage Principles

1. Test scripts in a non-production lab.
2. Validate results against native administrative tools.
3. Review generated evidence for sensitive information.
4. Apply peer review and change control before production adoption.
5. Record lessons learned and remediation outcomes.

## Current Automation Roadmap

| Artifact | Status |
|---|---|
| Active Directory baseline health script | Complete |
| Active Directory Health Assessment Toolkit | Complete, live validation pending |
| Hyper-V host readiness toolkit | Planned |
| DC01 deployment automation | Planned |
| Active Directory user provisioning module | Planned |
| Group Policy baseline validation | Planned |
| Windows Server health toolkit | Planned |
| GitHub Actions PowerShell quality gates | Future |

## Interview Talking Points

This automation portfolio demonstrates the ability to translate infrastructure operations into repeatable engineering controls, produce audit-friendly evidence, separate executive and technical reporting needs, and design tools that can later integrate with scheduled tasks, monitoring platforms, and CI pipelines.
