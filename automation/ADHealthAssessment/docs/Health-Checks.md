# Active Directory Health Checks

This document explains each validation performed by `Invoke-ADHealthAssessment.ps1`, why it matters, common failure causes, and recommended response actions.

## Forest and Domain Discovery

**Purpose:** Confirms the script is querying the intended Active Directory environment and records functional levels for operational context.

**Common issues:** Missing RSAT module, broken domain connectivity, insufficient permissions, or DNS misconfiguration.

**Response:** Verify domain membership, DNS client settings, network access, and `Get-ADForest`/`Get-ADDomain` execution.

## Domain Controller Count

**Purpose:** Identifies whether the domain has basic directory-service redundancy.

**Status logic:** Two or more domain controllers pass; one produces a warning.

**Response:** Deploy a second domain controller and validate replication, DNS registration, Global Catalog placement, and recovery procedures.

## Critical Services

The toolkit checks:

| Service | Function | Typical impact if unavailable |
|---|---|---|
| NTDS | Active Directory Domain Services | Authentication and directory queries fail |
| DNS | Name resolution for AD | Domain discovery and replication fail |
| Netlogon | Secure channel and locator registration | Logon and SRV registration problems |
| DFSR | SYSVOL replication | Group Policy inconsistency |
| W32Time | Time synchronization | Kerberos authentication failures |

**Response:** Review service dependencies and correlate with System, Directory Service, and DNS Server event logs before restarting services.

## Replication Summary

**Commands:**

```powershell
repadmin /replsummary
repadmin /showrepl
```

**Purpose:** Detects replication failures, latency, and partner-specific errors.

**Common causes:** DNS failures, firewall restrictions, stale metadata, broken secure channels, site/subnet errors, or unavailable domain controllers.

**Response:** Validate DNS first, confirm network reachability, identify the failing naming context and partner, and review replication event logs.

## DNS Zones

**Purpose:** Confirms that DNS zones can be enumerated and that the environment contains the zones required for directory operations.

**Common causes:** DNS role not installed locally, missing DNS tools, insufficient permissions, or unavailable DNS service.

**Response:** Run the assessment on an authorized management host with DNS tools, then verify AD-integrated zone configuration and replication scope.

## Domain Controller SRV Records

**Query:**

```powershell
Resolve-DnsName -Name _ldap._tcp.dc._msdcs.<forest-root> -Type SRV
```

**Purpose:** Verifies that clients can locate LDAP-capable domain controllers.

**Common causes:** Netlogon registration failure, incorrect DNS client settings, missing zone data, or replication problems.

**Response:** Verify the domain controller points to internal DNS, restart Netlogon in a controlled lab, run `nltest /dsregdns`, and validate zone replication.

## FSMO Role Holders

The toolkit records the Schema Master, Domain Naming Master, RID Master, PDC Emulator, and Infrastructure Master.

**Purpose:** Establishes role ownership for troubleshooting, maintenance planning, and disaster recovery.

**Response:** Confirm role holders are online and healthy. Do not seize roles unless the original holder is permanently unavailable and recovery has been approved.

## Event Log Review

The script queries critical and error events from the previous review window in:

- Directory Service
- DNS Server
- System

**Status logic:** No events pass; a small number generates a warning; higher volume fails.

**Engineering note:** Event count alone does not prove an outage. Findings must be correlated with event IDs, timestamps, affected services, and replication or DNS evidence.

## Result Statuses

| Status | Meaning |
|---|---|
| Pass | Expected condition verified |
| Warning | Degraded, incomplete, or potentially risky condition |
| Fail | Operational failure or major validation problem |
| Info | Inventory or contextual data |

## Operational Triage Order

1. Confirm DNS client configuration and name resolution.
2. Verify critical services.
3. Review replication summary and partner details.
4. Inspect Directory Service, DNS Server, and System events.
5. Confirm time synchronization and secure-channel health.
6. Document the incident, remediation, validation, and lessons learned.

## Limitations

The toolkit is a baseline assessment, not a replacement for `dcdiag`, performance monitoring, backup validation, security auditing, or full incident investigation. Production use requires peer review, testing, change control, and organization-specific thresholds.
