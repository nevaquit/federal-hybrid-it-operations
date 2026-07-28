<#
.SYNOPSIS
    Promotes DC01 as the first domain controller in the HJFB lab forest.
.DESCRIPTION
    Installs a new Active Directory forest named corp.hjfb.lab, configures the
    NetBIOS name HJFB, installs DNS, and writes a deployment summary before the
    required restart. The DSRM password is requested securely at runtime and is
    never written to disk.
.PARAMETER DomainName
    DNS name of the new forest root domain.
.PARAMETER DomainNetbiosName
    NetBIOS name of the new domain.
.PARAMETER InstallDns
    Installs and configures DNS during promotion. Enabled by default.
.PARAMETER NoRebootOnCompletion
    Prevents automatic restart after promotion.
.EXAMPLE
    .\Deploy-HJFBForest.ps1 -Confirm:$false
.NOTES
    Run locally from an elevated Windows PowerShell session on DC01 after
    Initialize-DC01.ps1 has completed and the server has restarted.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidatePattern('^(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$')]
    [string]$DomainName = 'corp.hjfb.lab',

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9]{1,15}$')]
    [string]$DomainNetbiosName = 'HJFB',

    [Parameter()]
    [bool]$InstallDns = $true,

    [Parameter()]
    [switch]$NoRebootOnCompletion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    if (-not (Test-IsAdministrator)) {
        throw 'This script must be run from an elevated PowerShell session.'
    }

    if ($env:COMPUTERNAME -ne 'DC01') {
        throw "Expected computer name DC01, but found $env:COMPUTERNAME."
    }

    $requiredFeatures = Get-WindowsFeature -Name AD-Domain-Services, DNS
    $missingFeatures = @($requiredFeatures | Where-Object InstallState -ne 'Installed')
    if ($missingFeatures.Count -gt 0) {
        throw "Required roles are not installed: $($missingFeatures.Name -join ', '). Run Initialize-DC01.ps1 first."
    }

    if (Get-ADDomain -ErrorAction SilentlyContinue) {
        throw 'This server already appears to be joined to or hosting an Active Directory domain.'
    }

    $safeModePassword = Read-Host 'Enter the Directory Services Restore Mode password' -AsSecureString
    if (-not $safeModePassword) {
        throw 'A DSRM password is required.'
    }

    $stateRoot = 'C:\ProgramData\HJFB-Lab\Logs'
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    $summaryPath = Join-Path $stateRoot ("Deploy-HJFBForest-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    $summary = [pscustomobject]@{
        Stage             = 'Forest deployment requested'
        GeneratedAt       = (Get-Date).ToString('o')
        ComputerName      = $env:COMPUTERNAME
        DomainName        = $DomainName
        DomainNetbiosName = $DomainNetbiosName
        InstallDns        = $InstallDns
        RebootSuppressed  = [bool]$NoRebootOnCompletion
        SecurityNote      = 'The DSRM password was supplied interactively and was not persisted.'
    }
    $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Create forest $DomainName")) {
        Import-Module ADDSDeployment -ErrorAction Stop
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetbiosName $DomainNetbiosName `
            -InstallDns:$InstallDns `
            -SafeModeAdministratorPassword $safeModePassword `
            -NoRebootOnCompletion:$NoRebootOnCompletion `
            -Force
    }
}
catch {
    Write-Error "Forest deployment failed: $($_.Exception.Message)"
    exit 2
}
