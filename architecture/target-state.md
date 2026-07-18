# Hybrid Infrastructure Target State

## Scenario

A fictional federal benefits organization operates mission-critical Windows services in a hybrid environment. The target state integrates on-premises Active Directory with Microsoft Entra ID and Azure-hosted resources while preserving operational resilience, least privilege, auditability, and recoverability.

## Core Components

- Two on-premises domain controllers with integrated DNS
- Tiered administrative model for privileged access
- Microsoft Entra ID for cloud identity and conditional access
- Azure virtual network with segmented subnets
- Network Security Groups aligned to application flows
- Azure Windows Server virtual machines
- Azure Storage for controlled file and log retention
- Azure Monitor and Log Analytics for centralized visibility
- Azure Backup with documented recovery procedures
- PowerShell-based health checks and reporting

## Design Principles

1. Protect production availability.
2. Enforce least privilege and separation of duties.
3. Standardize configuration and change control.
4. Monitor service health, capacity, and security events.
5. Validate backups through scheduled restore testing.
6. Maintain documented rollback procedures for every major change.

## Logical Flow

```text
Users and Administrators
        |
        v
On-Premises Active Directory ---- Microsoft Entra ID
        |                                  |
        v                                  v
Windows Servers                      Azure Services
        |                                  |
        +---------- Monitoring ------------+
        +---------- Backup ----------------+
        +---------- Security Logs ---------+
```

## Operational Outcomes

- Consistent identity governance across on-premises and cloud services
- Faster detection of service degradation
- Reduced risk from untested production changes
- Measurable backup, patching, and vulnerability-management performance
- Clear escalation paths for incidents and operational risks
