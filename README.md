<p align="center">
  <img src="docs/assets/logo_transparent.svg" alt="EasyPIM logo" width="180">
  <h1 align="center">🛡️ EasyPIM</h1>
  <p align="center">
    <strong>PowerShell automation for Azure Privileged Identity Management.</strong>
  </p>
  <p align="center">
    <a href="https://www.powershellgallery.com/packages/EasyPIM"><img src="https://img.shields.io/powershellgallery/v/easypim?label=Core&logo=powershell&color=blue" alt="Core Version"></a>
    <a href="https://www.powershellgallery.com/packages/EasyPIM.Orchestrator"><img src="https://img.shields.io/powershellgallery/v/EasyPIM.Orchestrator?label=Orchestrator&logo=powershell&color=blue" alt="Orchestrator Version"></a>
    <a href="https://www.powershellgallery.com/packages/EasyPIM"><img src="https://img.shields.io/powershellgallery/dt/easypim?label=Core%20Downloads&color=green" alt="Core Downloads"></a>
    <a href="https://www.powershellgallery.com/packages/EasyPIM.Orchestrator"><img src="https://img.shields.io/powershellgallery/dt/EasyPIM.Orchestrator?label=Orchestrator%20Downloads&color=green" alt="Orchestrator Downloads"></a>
    <a href="https://github.com/kayasax/EasyPIM/stargazers"><img src="https://img.shields.io/github/stars/kayasax/EasyPIM?style=social" alt="GitHub Stars"></a>
    <a href="https://github.com/kayasax/EasyPIM/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kayasax/EasyPIM" alt="License"></a>
  </p>
</p>

---

Bulk-harden role policies. Clone settings across roles. Export assignments. Detect configuration drift. Approve or deny requests. Deploy full PIM models from JSON.

**One PowerShell module covering Azure Resources, Entra ID Roles, and Security Groups** — with cmdlets that do what the portal can't. Unified ARM and Graph APIs, 50+ commands, 4 Azure clouds.

> 🌐 **Start here →** The **[EasyPIM Adoption Hub](https://kayasax.github.io/EasyPIM/)** walks you from first install to enterprise-grade PIM governance in three stages.

## 🚀 Quick Start

```powershell
Install-Module EasyPIM, EasyPIM.Orchestrator -Force

# Harden 3 Entra roles in one shot — try that in the portal
Set-PIMEntraRolePolicy -TenantID $tenantId `
    -RoleName "Global Administrator","Security Administrator","Exchange Administrator" `
    -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication" `
    -ActivationDuration "PT4H"

# Audit every eligible assignment across a subscription
Get-PIMAzureResourceEligibleAssignment -TenantID $tenantId -SubscriptionId $subId

# Deploy a full PIM model from JSON — Entra + Azure + Groups in one run
Invoke-EasyPIMOrchestrator -TenantId $tenantId -ConfigurationPath "./pim-config.json"
```

---

## ✨ Things The Portal Can't Do

| | |
|---|---|
| ⚡ **Bulk-harden roles** | Set MFA + justification + ticketing on 30 roles in one command |
| 🔄 **Clone role settings** | Copy a hardened policy to other roles/users — no manual re-clicking |
| 📊 **Export & import** | Assignments to CSV, full configs to JSON — audit-ready in seconds |
| 🔍 **Detect policy drift** | Compare live state vs declared config, get a diff report |
| 🏢 **CI/CD governance** | GitHub Actions & Azure DevOps ([Event-Driven Demo](https://github.com/kayasax/EasyPIM-EventDriven-Governance)) |
| ☁️ **Multi-cloud** | Public, Government, China, Germany — same cmdlets everywhere |
| 🔗 **Unified ARM + Graph** | One module abstracts both APIs — no context-switching |

---

## 📦 Install

```powershell
Install-Module EasyPIM, EasyPIM.Orchestrator -Scope CurrentUser
```

| Requirement | Details |
|---|---|
| PowerShell | 5.1+ or 7.0+ |
| Modules | `Az.Accounts`, `Microsoft.Graph.Authentication` (auto-installed) |
| Azure Resources | `Owner` or `User Access Administrator` on the subscription |
| Entra ID / Groups | Graph permissions: `RoleManagement.ReadWrite.Directory`, `RoleManagementPolicy.ReadWrite.Directory`, and [others](https://github.com/kayasax/EasyPIM/wiki/Documentation) |

---

## 📖 Learn More

| | |
|---|---|
| **[🌐 Adoption Hub](https://kayasax.github.io/EasyPIM/)** | **Three-stage journey: quick-starts, best practices, enterprise patterns** |
| [📋 Full Documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation) | In-depth guides and API reference |
| [🎯 Use Cases & Examples](https://github.com/kayasax/EasyPIM/wiki/Use-Cases) | Real-world implementation scenarios |
| [🏗 Orchestrator Guide](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide) | JSON-driven workflows step-by-step |
| [🔄 Migration v1→v2](https://github.com/kayasax/EasyPIM/wiki/Module-Migration) | Upgrading from v1.x |
| [📝 Changelog](https://github.com/kayasax/EasyPIM/wiki/Changelog) | Version history |

---

## 🔧 Two Modules, One Platform

| Module | Purpose | Key Commands |
|---|---|---|
| **EasyPIM** (Core) | Direct PIM API management — policies, assignments, approvals | `Get-PIM*`, `Set-PIM*`, `New-PIM*` |
| **EasyPIM.Orchestrator** | JSON workflows, drift detection, business rules, CI/CD | `Invoke-EasyPIMOrchestrator`, `Test-PIMPolicyDrift` |

<details>
<summary>Click to expand the full cmdlet list (50+)</summary>

### Azure Resource Roles

| Cmdlet | Description |
|---|---|
| `Get-PIMAzureResourcePolicy` | Get role policy settings |
| `Set-PIMAzureResourcePolicy` | Configure activation requirements, duration, approvers |
| `Get-PIMAzureResourceEligibleAssignment` | List eligible assignments |
| `New-PIMAzureResourceEligibleAssignment` | Create eligible assignment |
| `Remove-PIMAzureResourceEligibleAssignment` | Remove eligible assignment |
| `Get-PIMAzureResourceActiveAssignment` | List active assignments |
| `New-PIMAzureResourceActiveAssignment` | Create active assignment |
| `Remove-PIMAzureResourceActiveAssignment` | Remove active assignment |

### Entra ID Roles

| Cmdlet | Description |
|---|---|
| `Get-PIMEntraRolePolicy` | Get Entra role policy settings |
| `Set-PIMEntraRolePolicy` | Configure activation requirements, MFA, approvers |
| `Get-PIMEntraRoleEligibleAssignment` | List eligible assignments |
| `New-PIMEntraRoleEligibleAssignment` | Create eligible assignment |
| `Remove-PIMEntraRoleEligibleAssignment` | Remove eligible assignment |
| `Get-PIMEntraRoleActiveAssignment` | List active assignments |
| `New-PIMEntraRoleActiveAssignment` | Create active assignment |
| `Remove-PIMEntraRoleActiveAssignment` | Remove active assignment |

### Groups

| Cmdlet | Description |
|---|---|
| `Get-PIMGroupPolicy` | Get group PIM policy settings |
| `Set-PIMGroupPolicy` | Configure group activation requirements |
| `Get-PIMGroupEligibleAssignment` | List eligible group assignments |
| `New-PIMGroupEligibleAssignment` | Create eligible group assignment |
| `Remove-PIMGroupEligibleAssignment` | Remove eligible group assignment |
| `Get-PIMGroupActiveAssignment` | List active group assignments |
| `New-PIMGroupActiveAssignment` | Create active group assignment |
| `Remove-PIMGroupActiveAssignment` | Remove active group assignment |

### Operations & Utilities

| Cmdlet | Description |
|---|---|
| `Approve-PIMPendingRequest` | Approve pending activation requests |
| `Deny-PIMPendingRequest` | Deny pending activation requests |
| `Get-PIMReport` | PIM activity analytics and audit trails |
| `Backup-PIMConfiguration` | Full PIM state backup |
| `Restore-PIMConfiguration` | Restore from backup |
| `Copy-PIMRoleSettings` | Clone settings between roles |
| `Export-PIMAssignment` | Export assignments to CSV |
| `Import-PIMAssignment` | Import assignments from CSV |

### Orchestrator

| Cmdlet | Description |
|---|---|
| `Invoke-EasyPIMOrchestrator` | Deploy complete PIM configuration from JSON |
| `Test-PIMPolicyDrift` | Detect policy drift against declared state |
| `Test-PIMEndpointDiscovery` | Connectivity and permissions validation |

</details>

---

## 🌐 Coverage

**3 PIM scopes**: Azure Resources (subscription, management group, resource group) · Entra ID Roles · Security Groups

**4 clouds**: Public · Government · China · Germany

---

## 🤝 Related Projects

| | |
|---|---|
| **[EasyTCM](https://github.com/kayasax/EasyTCM)** | Tenant Configuration Monitoring — detect config drift across Entra, Exchange, Intune, Teams & Compliance |
| **[Event-Driven Governance](https://github.com/kayasax/EasyPIM-EventDriven-Governance)** | Production CI/CD demo: GitHub Actions + Azure DevOps + Event Grid |

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Contributors

- **[Loïc MICHEL](https://github.com/kayasax)** — Author and maintainer
- **[Chase Dafnis](https://github.com/CHDAFNI-MSFT)** — Multi-cloud / Azure environment support
- **[jeenvan](https://github.com/jeevanions)** — Orchestrator: array format & management group scope fixes

---

<p align="center">
  Built with ❤️ for the Azure Administrator Community<br>
  <strong>Also by the author: <a href="https://github.com/kayasax/EasyTCM">EasyTCM</a> — M365 tenant config drift detection</strong>
</p>
