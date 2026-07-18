# Hybrid Identity and Access Design

## Objectives

- Provide one authoritative identity lifecycle.
- Apply least privilege and role-based access.
- Separate standard and privileged activity.
- Maintain auditable joiner, mover, and leaver controls.
- Support secure access to on-premises and Azure services.

## Organizational Unit Model

```text
Agency
├── Users
│   ├── Headquarters
│   ├── Regional-Offices
│   ├── Contractors
│   └── Service-Accounts
├── Workstations
│   ├── Standard
│   └── Privileged-Access
├── Servers
│   ├── Domain-Controllers
│   ├── Infrastructure
│   └── Applications
└── Groups
    ├── Role-Groups
    ├── Resource-Groups
    └── Administrative-Groups
```

## Access Model

Use role groups to represent job responsibilities and resource groups to represent permissions. Nest approved role groups into resource groups rather than assigning users directly to resources.

Examples:

- `GG-Role-Benefits-Analyst`
- `DL-Share-Benefits-Read`
- `GG-Role-Server-Operators`
- `DL-Server-Management-RDP`

## Privileged Administration

- Administrators use separate standard and privileged accounts.
- Domain-level privileges are restricted to designated personnel.
- Cloud privileged roles require multifactor authentication.
- Privileged access is time-limited when the platform supports it.
- Administrative activity is logged and reviewed.
- Local administrator credentials are managed through Microsoft LAPS.

## Account Lifecycle

### Joiner

1. Confirm approved request and manager.
2. Create account using standardized naming.
3. Assign department and role groups.
4. Require secure first-use credential process.
5. Record completion and validation.

### Mover

1. Confirm new manager and effective date.
2. Remove access no longer justified.
3. Add approved role access.
4. Review privileged memberships.
5. Document the access change.

### Leaver

1. Disable interactive access at the authorized time.
2. Revoke sessions and cloud tokens.
3. Remove privileged roles and remote access.
4. Preserve data according to retention requirements.
5. Transfer ownership of business records.
6. Delete the account only after the retention period.

## Group Policy Baseline

- Password and account-lockout policy
- Windows Defender and firewall configuration
- Audit policy and PowerShell logging
- Screen lock and inactivity timeout
- Removable-media restrictions
- Local administrator controls
- Remote Desktop restrictions
- Event forwarding configuration

## Review Cadence

- Weekly: privileged-group changes
- Monthly: inactive and stale accounts
- Quarterly: manager access recertification
- Annually: identity architecture and policy review
