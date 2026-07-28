# DC01 Deployment Automation

This package prepares, promotes, and validates the first domain controller in the Henry Jenkins Federal Benefits lab.

## Purpose

The scripts convert the documented architecture into a repeatable implementation workflow for:

- Server naming and static IPv4 configuration
- AD DS, DNS, and DHCP role installation
- New forest deployment for `corp.hjfb.lab`
- Secure, interactive DSRM password entry
- Post-deployment validation and report generation

## Files

| File | Purpose |
|---|---|
| `Initialize-DC01.ps1` | Prepares the Windows Server VM, configures networking, renames it to DC01, and installs required roles |
| `Deploy-HJFBForest.ps1` | Creates the `corp.hjfb.lab` forest and DNS service |
| `Test-DC01Deployment.ps1` | Performs read-only validation and generates HTML and JSON evidence |

## Intended Lab Configuration

| Setting | Value |
|---|---|
| Computer name | `DC01` |
| Domain | `corp.hjfb.lab` |
| NetBIOS name | `HJFB` |
| IPv4 address | `10.20.0.10/24` |
| Gateway | `10.20.0.1` |
| Initial DNS server | `10.20.0.10` |
| Hyper-V switch | `LAB-NAT` |

## Execution Sequence

Run all commands from an elevated Windows PowerShell session inside the DC01 virtual machine.

### 1. Review the planned changes

```powershell
.\Initialize-DC01.ps1 -InterfaceAlias Ethernet -WhatIf
```

### 2. Prepare the server

```powershell
.\Initialize-DC01.ps1 -InterfaceAlias Ethernet -Restart -Confirm:$false
```

After the server restarts, verify its hostname and network settings.

### 3. Deploy the forest

```powershell
.\Deploy-HJFBForest.ps1 -Confirm:$false
```

The script requests the Directory Services Restore Mode password securely at runtime. It never stores that password in the repository or deployment summary.

### 4. Validate the deployment

```powershell
.\Test-DC01Deployment.ps1 -OutputDirectory C:\Evidence\DC01
```

### 5. Run the broader health assessment

After the deployment validator passes, run:

```powershell
..\ADHealthAssessment\Invoke-ADHealthAssessment.ps1 -OutputDirectory C:\Evidence\ADHealth
```

## Evidence Produced

The preparation script stores local logs under:

```text
C:\ProgramData\HJFB-Lab\Logs
```

The validation script generates:

- `DC01-Validation.html`
- `DC01-Validation.json`

Before publishing evidence, remove or replace any internal identifiers that should not be public.

## Validation Standard

DC01 is considered successfully deployed when:

- The server name is `DC01`.
- The domain is `corp.hjfb.lab`.
- AD DS, DNS, Netlogon, DFSR, Windows Time, and DHCP services are running.
- SYSVOL and NETLOGON shares exist.
- LDAP domain-controller SRV records resolve.
- `dcdiag /q` returns no errors.
- The deployment validator produces its HTML and JSON reports.
- The Active Directory Health Assessment Toolkit runs successfully.

A replication warning is acceptable before DC02 exists because the initial forest contains only one domain controller.

## Security and Change Controls

- Use only in an isolated, non-production lab.
- Do not commit passwords, secrets, product keys, or unsanitized internal data.
- Review `-WhatIf` output before applying changes.
- Capture a Hyper-V checkpoint only before a controlled change and remove it after successful validation.
- Treat checkpoints as temporary recovery aids, not backups.
- Review generated reports before publishing them.

## Rollback Guidance

Before forest promotion, revert the lab VM to the controlled pre-promotion checkpoint or rebuild the VM from the documented baseline.

After forest promotion, do not attempt to repair an uncertain first-domain-controller deployment by repeatedly rerunning promotion commands. In a disposable lab, the safest recovery path is usually to document the failure, revert to the pre-promotion checkpoint, correct the prerequisite issue, and redeploy.

## Interview Talking Points

This artifact demonstrates:

- Phased infrastructure automation rather than one monolithic script
- Idempotent prerequisite handling where practical
- Secure secret handling through runtime prompts
- PowerShell `ShouldProcess` and `-WhatIf` support
- Structured evidence generation
- Native-tool validation using `dcdiag`, `repadmin`, DNS, SMB shares, services, and Active Directory cmdlets
- Clear separation between deployment and validation responsibilities

## Next Enhancements

- DHCP scope configuration automation
- DNS forwarder and reverse-zone automation
- Pester tests for parameter validation and helper functions
- PSScriptAnalyzer enforcement through GitHub Actions
- Sanitized live validation reports after DC01 is deployed
