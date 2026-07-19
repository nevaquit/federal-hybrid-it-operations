# Active Directory Health Assessment Automation

## Purpose

`Test-ADHealth.ps1` provides a repeatable, read-only assessment of core Active Directory operational health. It is designed as both an engineering portfolio artifact and a practical starting point for daily or weekly domain-services checks.

## Operational Value

The script reduces the time required to collect basic domain-controller evidence and standardizes how results are recorded. It checks:

- Domain controller network reachability
- Active Directory, DNS, Netlogon, Kerberos, time, and DFS Replication services
- SYSVOL and NETLOGON share availability
- DNS host registration
- Domain controller system-drive free space
- Windows time synchronization
- Active Directory replication failures
- DCDIAG results when the utility is available

## Prerequisites

- Windows PowerShell 5.1 or later
- Active Directory PowerShell module
- An account with permission to query domain controllers remotely
- DNS resolution and network access to each domain controller
- WinRM or CIM connectivity for remote disk checks
- `dcdiag.exe` for optional diagnostic testing

## Usage

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Import-Module ActiveDirectory
.\Test-ADHealth.ps1 -OutputPath C:\Evidence\AD-Health
```

To omit DCDIAG:

```powershell
.\Test-ADHealth.ps1 -OutputPath C:\Evidence\AD-Health -SkipDcDiag
```

## Output

The script produces:

- A color-neutral console table suitable for remote administrative sessions
- A timestamped CSV file for filtering and reporting
- A timestamped JSON file for integration with dashboards or other automation
- Per-domain-controller DCDIAG text files when DCDIAG is enabled

Exit codes support scheduled-task or monitoring integration:

| Exit code | Meaning |
|---:|---|
| `0` | All completed checks passed |
| `1` | One or more warnings were detected |
| `2` | One or more failures were detected |

## Validation Procedure

1. Run the script from a domain-joined administrative workstation in a test environment.
2. Confirm every expected domain controller appears in the results.
3. Verify the CSV and JSON evidence files are created.
4. Compare replication output with `repadmin /replsummary`.
5. Compare diagnostic output with an independently executed `dcdiag /e /v` command.
6. Temporarily stop a noncritical test service in a lab and confirm the script records a failure.
7. Restore the service and verify the next run returns to a passing state.

## Security and Change Controls

- The script performs read-only checks and does not modify Active Directory.
- Credentials are not stored in the repository or written to evidence files.
- Evidence files may contain internal hostnames and IP addresses, so protect them according to organizational data-handling requirements.
- Production adoption should follow peer review, non-production testing, change approval, and rollback planning.

## Interview Talking Points

This artifact demonstrates the ability to:

- Translate operational requirements into repeatable automation
- Use structured PowerShell objects instead of unstructured console text
- Produce machine-readable evidence for reporting and audit support
- Incorporate error handling and meaningful process exit codes
- Design automation that supports operations without making unauthorized changes

## Future Enhancements

- HTML executive dashboard
- Event log analysis for directory-services warnings and errors
- DNS zone and scavenging validation
- FSMO role-holder validation
- SYSVOL replication backlog monitoring
- Certificate-expiration checks for LDAPS
- Scheduled execution with email or Microsoft Teams notification
- Pester tests and ScriptAnalyzer enforcement in GitHub Actions
