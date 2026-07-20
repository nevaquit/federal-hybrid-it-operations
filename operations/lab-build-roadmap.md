# Enterprise Lab Build Roadmap

This roadmap converts the architecture blueprint into an evidence-based implementation program. Each phase produces a working capability, validation evidence, GitHub documentation, and interview-ready talking points.

## Status Legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete

## Phase 0 — Host Readiness

- [ ] Confirm virtualization support in Task Manager and firmware
- [ ] Enable Hyper-V, Hyper-V Management Tools, and Windows Sandbox
- [ ] Create `C:\Hyper-V` storage structure
- [ ] Record host CPU, memory, storage, operating system, and security configuration
- [ ] Create a host recovery point and export current configuration

**Deliverables**

- Host readiness checklist
- Sanitized system information screenshot
- Hyper-V feature validation output

## Phase 1 — Hyper-V Network Foundation

- [ ] Create `LAB-NAT` internal virtual switch
- [ ] Assign host adapter `10.20.0.1/24`
- [ ] Create Windows NAT object for `10.20.0.0/24`
- [ ] Create `LAB-MGMT` private or internal virtual switch
- [ ] Assign management network settings
- [ ] Validate guest-to-host, guest-to-guest, and controlled internet connectivity

**Deliverables**

- Hyper-V networking PowerShell script
- Network validation report
- Architecture screenshot and Mermaid diagram

## Phase 2 — DC01 and Forest Deployment

- [ ] Create DC01 Generation 2 VM
- [ ] Install Windows Server Evaluation
- [ ] Rename server and apply static IP configuration
- [ ] Install AD DS, DNS, and DHCP roles
- [ ] Create forest `corp.hjfb.lab`
- [ ] Configure DNS forwarders and reverse lookup zone
- [ ] Configure and authorize DHCP scope
- [ ] Capture baseline health evidence

**Deliverables**

- DC01 deployment script
- Forest deployment guide
- DNS and DHCP configuration documentation
- AD health report

## Phase 3 — Identity and Group Policy Baseline

- [ ] Create enterprise OU structure
- [ ] Create role-based security groups
- [ ] Create test users and service accounts
- [ ] Implement AGDLP access model
- [ ] Deploy password and lockout policy
- [ ] Deploy firewall, Defender, audit, PowerShell logging, and screen-lock GPOs
- [ ] Back up all GPOs

**Deliverables**

- OU and identity provisioning scripts
- Group Policy matrix
- GPO backup package
- Least-privilege design document

## Phase 4 — CLIENT01 Integration

- [ ] Create Windows 11 evaluation client
- [ ] Configure DHCP and domain DNS
- [ ] Join `corp.hjfb.lab`
- [ ] Validate standard-user sign-in
- [ ] Validate GPO application with `gpresult`
- [ ] Test administrative separation
- [ ] Capture Event Viewer and Group Policy evidence

**Deliverables**

- Domain-join script
- Client validation checklist
- Sanitized screenshots and command output

## Phase 5 — DC02 Redundancy

- [ ] Create and patch DC02
- [ ] Promote DC02 as an additional domain controller
- [ ] Install DNS and Global Catalog
- [ ] Validate SYSVOL and AD replication
- [ ] Test DNS and authentication failover
- [ ] Practice FSMO role transfer and recovery

**Deliverables**

- Additional-DC deployment procedure
- Replication troubleshooting runbook
- Failover test report

## Phase 6 — FILE01 Enterprise File Services

- [ ] Create FILE01 and join the domain
- [ ] Add separate data VHDX
- [ ] Configure SMB shares and NTFS permissions
- [ ] Implement AGDLP access assignments
- [ ] Configure quotas and file screening
- [ ] Configure DFS namespace
- [ ] Test backup and file restoration

**Deliverables**

- File-services deployment script
- Permissions matrix
- Backup and restore evidence

## Phase 7 — Central Management and Monitoring

- [ ] Create MGMT01
- [ ] Install RSAT and Windows Admin Center
- [ ] Configure PowerShell remoting securely
- [ ] Configure Windows Event Forwarding
- [ ] Create daily health-check procedures
- [ ] Schedule AD and server health reports
- [ ] Establish operational dashboard inputs

**Deliverables**

- Management-server build guide
- Daily operations checklist
- Monitoring and alerting runbook

## Phase 8 — PKI and Certificate Services

- [ ] Design offline root and enterprise issuing CA model
- [ ] Deploy lab certificate authority
- [ ] Create certificate templates
- [ ] Configure auto-enrollment
- [ ] Issue certificates for servers, users, and IIS
- [ ] Test revocation and renewal

**Deliverables**

- PKI architecture
- Certificate lifecycle runbook
- Deployment and validation evidence

## Phase 9 — Patching and Vulnerability Management

- [ ] Deploy WSUS when host memory permits
- [ ] Create workstation and server patch rings
- [ ] Establish approval and maintenance windows
- [ ] Document rollback and exception handling
- [ ] Produce patch-compliance report
- [ ] Conduct a vulnerability remediation exercise

**Deliverables**

- Patch management standard
- Vulnerability remediation report
- Executive compliance summary

## Phase 10 — Disaster Recovery

- [ ] Define recovery time and recovery point objectives
- [ ] Back up system state and critical data
- [ ] Export Hyper-V configurations
- [ ] Test authoritative and non-authoritative AD recovery concepts
- [ ] Restore deleted objects and files
- [ ] Conduct a documented recovery exercise

**Deliverables**

- Disaster recovery plan
- Recovery test report
- Lessons-learned document

## Phase 11 — Azure Hybrid Expansion

- [ ] Activate eligible student Azure benefits
- [ ] Create a controlled Azure resource group and budget alerts
- [ ] Design Azure VNet and network security groups
- [ ] Evaluate Entra ID and hybrid identity options
- [ ] Connect selected servers to Azure Arc where appropriate
- [ ] Add Azure Monitor, Log Analytics, Backup, or automation selectively
- [ ] Shut down or remove chargeable resources after demonstrations

**Deliverables**

- Hybrid architecture diagram
- Azure cost-control standard
- Cloud validation evidence

## Phase 12 — Portfolio Packaging

- [ ] Add sanitized screenshots for each completed phase
- [ ] Record short technical walkthrough videos
- [ ] Add architecture decision records
- [ ] Add change requests and incident simulations
- [ ] Add resume-ready accomplishment statements
- [ ] Link the repository from the personal portfolio website and LinkedIn

**Completion Standard**

A portfolio phase is complete only when the implementation works, validation is documented, evidence is sanitized, and the repository explains the business purpose, technical design, security controls, operational procedures, and lessons learned.
