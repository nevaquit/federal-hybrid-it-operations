# Target-State Hybrid Architecture

## Objective

Provide a secure, supportable, and recoverable Microsoft hybrid environment for a mission-focused federal organization while minimizing disruption to production services.

## Core Components

| Layer | Components | Operational Purpose |
|---|---|---|
| Identity | Active Directory Domain Services, Microsoft Entra ID | Central authentication, authorization, and lifecycle management |
| Compute | On-premises Windows Server, Azure Windows virtual machines | Application and infrastructure hosting |
| Network | Segmented LAN, Azure Virtual Network, subnets, NSGs, site-to-site connectivity | Controlled communication between users, services, and management systems |
| Storage | Managed disks, Azure Storage Account, protected file services | Durable data storage and controlled sharing |
| Operations | Azure Monitor, Windows Event Forwarding, PowerShell reporting | Health, capacity, security, and service visibility |
| Recovery | System-state backup, Azure Backup, documented restore procedures | Recovery from deletion, corruption, failure, or cyber incident |
| Governance | Change control, incident management, vulnerability management | Stable production operations and auditable decisions |

## Network Segmentation

- Management subnet for administrative services
- Server subnet for infrastructure and application workloads
- User subnet for standard workstations
- Restricted backup and recovery path
- Explicit NSG rules using least-privilege source, destination, protocol, and port definitions
- No direct public administrative access to servers

## Identity Flow

1. Human resources or management authorizes access.
2. IT creates or updates the on-premises identity.
3. Approved attributes and group memberships synchronize to Microsoft Entra ID.
4. Conditional Access and role assignment govern cloud access.
5. Privileged roles use separate administrative accounts.
6. Joiner, mover, and leaver events are logged and reviewed.

## Availability Design

- Two domain controllers on separate hosts or fault domains
- Redundant DNS services
- Backup of Active Directory system state
- Monitored replication, authentication, storage, and network health
- Defined recovery time and recovery point objectives
- Documented manual operating procedures when cloud or on-premises connectivity is degraded

## Security Controls

- Least privilege and role-based access
- Administrative tiering
- Multifactor authentication for privileged cloud access
- Microsoft LAPS for local administrator password management
- Centralized logging and alerting
- Monthly vulnerability review
- Risk-based patch prioritization
- Controlled service accounts and credential rotation
- Quarterly access recertification

## Operational Acceptance Criteria

The environment is accepted only after:

- Identity synchronization is validated
- DNS resolution works across approved network paths
- Backup jobs complete and a restore test succeeds
- Monitoring alerts are received and acknowledged
- NSG rules pass connectivity and denial tests
- Administrative access follows approved privileged-access procedures
- Rollback steps are verified
- Support documentation and ownership are assigned
