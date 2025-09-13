# 🛡️ EasyPIM - Enterprise Privileged Identity Management Automation

[![PSGallery Version](https://img.shields.io/powershellgallery/v/easypim.svg?style=for-the-badge&logo=powershell&label=Core%20Version)](https://www.powershellgallery.com/packages/easypim) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/easypim.svg?style=for-the-badge&logo=powershell&label=Core%20Downloads)](https://www.powershellgallery.com/packages/easypim)

[![Orchestrator Version](https://img.shields.io/powershellgallery/v/EasyPIM.Orchestrator.svg?style=for-the-badge&logo=powershell&label=Orchestrator%20Version)](https://www.powershellgallery.com/packages/EasyPIM.Orchestrator) [![Orchestrator Downloads](https://img.shields.io/powershellgallery/dt/EasyPIM.Orchestrator.svg?style=for-the-badge&logo=powershell&label=Orchestrator%20Downloads)](https://www.powershellgallery.com/packages/EasyPIM.Orchestrator)

[![GitHub Stars](https://img.shields.io/github/stars/kayasax/EasyPIM?style=for-the-badge&logo=github)](https://github.com/kayasax/EasyPIM/stargazers) [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE) [![GitHub Issues](https://img.shields.io/github/issues/kayasax/EasyPIM?style=for-the-badge&logo=github)](https://github.com/kayasax/EasyPIM/issues)

---

## 💡 **Transform Azure PIM Management from Manual to Intelligent Automation**

**EasyPIM** is the most comprehensive PowerShell automation platform for Microsoft Privileged Identity Management (PIM). With **50+ specialized cmdlets**, EasyPIM transforms complex ARM and Graph API interactions into simple, reliable automation workflows for **Azure Resources**, **Entra ID Roles**, and **Security Groups**.

### 🎯 **What Makes EasyPIM Different**
- **🚀 Event-Driven Automation**: Complete CI/CD integration with GitHub Actions & Azure DevOps
- **🛡️ Enterprise Security**: Zero-trust architecture with OIDC authentication
- **📊 Business Rules Engine**: Intelligent policy validation and drift detection  
- **⚡ Production Ready**: Powers enterprise PIM governance at scale
- **🔄 Multi-Cloud Support**: Public, Government, China, Germany clouds

> **🆕 NEW**: Experience EasyPIM in production with our [**Event-Driven Governance Demo**](https://github.com/kayasax/EasyPIM-EventDriven-Governance) - complete CI/CD automation with enterprise dashboards!

---

## 📋 **Table of Contents**
- [🚀 Quick Start](#-quick-start) • [🎯 Key Features](#-key-features) • [📦 Installation](#-installation)
- [💼 Enterprise Demo](#-enterprise-demo) • [📚 Documentation](#-documentation) • [🔧 Troubleshooting](#-troubleshooting)
- [🆕 Latest Release](#-major-release-easypim-v20--orchestrator-v10) • [🤝 Contributing](#-contributors)

---

## 🚀 **Quick Start**

```powershell
# 1. Install both modules for complete functionality
Install-Module -Name EasyPIM, EasyPIM.Orchestrator -Force

# 2. Import and discover commands
Import-Module EasyPIM, EasyPIM.Orchestrator
Get-Command -Module EasyPIM*

# 3. Start with basic PIM operations
Get-PIMAzureResourcePolicy -TenantID $tenantID -SubscriptionId $subscriptionID -RoleName "reader"
```

**⚡ Ready for Production?** → **[Deploy Event-Driven PIM Governance](https://github.com/kayasax/EasyPIM-EventDriven-Governance)** with complete CI/CD automation!

---

## 💼 **Enterprise Demo: Event-Driven PIM Governance**

### 🎯 **[EasyPIM Event-Driven Governance Platform](https://github.com/kayasax/EasyPIM-EventDriven-Governance)**

Experience EasyPIM in a **production-ready enterprise environment** with our comprehensive demo repository featuring:

| 🚀 **Enterprise Features** | 📊 **Business Value** | 
|---|---|
| **⚡ Event-Driven Architecture** | Instant policy updates via Azure Event Grid triggers |
| **🛡️ Zero-Trust Security** | OIDC authentication, no stored secrets, Key Vault encryption |
| **📋 Business Rules Engine** | 100% configuration accuracy with intelligent validation |
| **🎛️ Professional Dashboards** | Real-time monitoring, compliance reporting, drift detection |
| **⚖️ Dual Platform Support** | GitHub Actions + Azure DevOps integration |
| **🔄 Self-Healing Systems** | Automatic remediation and 24/7 autonomous operations |

#### 🎯 **What You'll Learn:**
- **CI/CD Integration**: Complete GitHub Actions & Azure DevOps pipeline setup
- **Enterprise Security**: Zero-trust architecture implementation
- **Business Rules**: Custom policy validation and governance frameworks
- **Monitoring**: Professional dashboards with real-time compliance tracking
- **Automation**: Event-driven responses to configuration changes

**👉 [Start the Demo](https://github.com/kayasax/EasyPIM-EventDriven-Governance) • [Step-by-Step Guide](https://github.com/kayasax/EasyPIM-EventDriven-Governance/blob/main/docs/Step-by-Step-Guide.md)**

---

## 🆕 **Major Release: EasyPIM v2.0 & Orchestrator v1.0**

- 🎯 **Major architectural milestone**: Complete module separation
- 🔧 **ARM API compatibility fixes**: Resolves InvalidResourceType errors
- 🛡️ **Enhanced policy validation**: Proactive error detection with clear guidance
- 📏 **Parameter standardization**: Consistent naming with backward compatibility
- 🏗️ **Production-ready orchestrator**

⚠️ **Breaking Changes in v2.0**: Parameter `assignee` renamed to `principalId` (alias provided for compatibility)

🆕 **Module separation complete**: The JSON-driven orchestrator is now a standalone module: EasyPIM.Orchestrator (requires EasyPIM ≥ 2.0.0).
**Orchestrated flow guide:** [step-by-step](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)
🌍 EasyPIM supports multi-cloud (Public, Government, China, Germany) thanks to [Chase Dafnis](https://github.com/CHDAFNI-MSFT)!

## 🎯 **Key Features**
### 🏗️ **Core PIM Management**
- ⚡ **Bulk Operations**: Edit multiple roles simultaneously with advanced filtering
- 🔄 **Role Cloning**: Copy settings and assignments between roles/users with validation
- 📊 **CSV Integration**: Export/import role configurations with data transformation
- 🛡️ **Backup & Restore**: Complete PIM state backup with versioning support
- 📈 **Activity Reporting**: Comprehensive PIM activity analytics and audit trails
- ✅ **Request Management**: Approve/deny pending requests with workflow automation

### 🎯 **Advanced Orchestration** (EasyPIM.Orchestrator)
- 🏗️ **JSON-Driven Workflows**: Define complete PIM models (Entra, Azure RBAC, Groups) declaratively  
- 📋 **Policy Drift Detection**: Continuous compliance monitoring with automated remediation
- 🛡️ **Business Rules Engine**: Intelligent validation preventing misconfigurations
- � **CI/CD Integration**: Production-ready automation for GitHub Actions & Azure DevOps
- 📊 **Enterprise Dashboards**: Professional monitoring with real-time compliance metrics
- ⚡ **Event-Driven Architecture**: Instant responses to configuration changes via Event Grid

### 🌍 **Enterprise Ready**
- ☁️ **Multi-Cloud Support**: Azure Public, Government, China, Germany environments
- 🛡️ **Zero-Trust Security**: OIDC authentication, Key Vault integration, no stored secrets
- 📏 **Standardized APIs**: Consistent parameter naming with backward compatibility
- 🏢 **Production Validated**: Powers enterprise PIM governance at scale

---

## � **Installation**

### 🚀 **Quick Install** (Recommended)
```powershell
# Install both modules with latest versions
Install-Module -Name EasyPIM, EasyPIM.Orchestrator -Force -Scope CurrentUser

# Verify installation
Get-Module -Name EasyPIM* -ListAvailable | Select-Object Name, Version
```

### 🔧 **Getting Started**
```powershell
# Import modules and discover available commands
Import-Module EasyPIM, EasyPIM.Orchestrator
Get-Command -Module EasyPIM* | Measure-Object  # 50+ cmdlets available!

# Quick connectivity test
Connect-AzAccount  # Required for Azure Resource roles
Connect-MgGraph    # Required for Entra ID roles and groups
```

### ⚡ **Ready for Production?**
Skip manual configuration and jump straight to enterprise automation:
**👉 [Deploy Event-Driven PIM Governance](https://github.com/kayasax/EasyPIM-EventDriven-Governance) - Complete CI/CD setup in 10 minutes!**

---

## 🎯 **Sample Usage & Common Scenarios**

*Note: EasyPIM manages PIM Azure Resource settings **at the subscription level by default**. Use the `scope` parameter for Management Group, Resource Group, or Resource-level management.*

### 🔍 **Policy Discovery & Analysis**
```powershell
# Get configuration of multiple Azure Resource roles
Get-PIMAzureResourcePolicy -TenantID $tenantID -SubscriptionId $subscriptionID -RoleName "reader","contributor","owner"

# Analyze Entra ID role configurations
Get-PIMEntraRolePolicy -TenantID $tenantID -RoleName "Global Administrator","Security Administrator"
```

### 🛡️ **Security Hardening**
```powershell
# Require MFA, justification, and ticketing for critical Entra roles
Set-PIMEntraRolePolicy -TenantID $tenantID -RoleName "Global Administrator" `
    -ActivationRequirement "Justification","Ticketing","MultiFactorAuthentication" `
    -ActivationDuration "PT4H"

# Configure approval workflow for Azure resource roles
Set-PIMAzureResourcePolicy -TenantID $tenantID -SubscriptionId $subscriptionID `
    -RoleName "Owner","Contributor" `
    -Approvers @(@{"Id"="user-guid";"Name"="John Doe";"Type"="user"}) `
    -ApprovalRequired $true
```

### 👥 **Assignment Management**
```powershell
# List all eligible assignments for audit
Get-PIMAzureResourceEligibleAssignment -TenantID $tenantID -SubscriptionId $subscriptionID

# Create time-limited active assignment
New-PIMEntraRoleActiveAssignment -TenantID $tenantID -RoleName "Security Reader" `
    -PrincipalId $userGuid -Duration "PT8H" -Justification "Security audit"
```

### 🏗️ **Enterprise Orchestration**
```powershell
# Deploy complete PIM configuration from JSON
Invoke-EasyPIMOrchestrator -TenantId $tenantId -ConfigurationPath "./pim-config.json"

# Detect and report policy drift
Test-PIMPolicyDrift -TenantId $tenantId -ConfigurationPath "./pim-config.json" -ReportPath "./drift-report.json"
```

**💡 Want more examples?** Check our [**Event-Driven Governance Demo**](https://github.com/kayasax/EasyPIM-EventDriven-Governance) for production-ready automation scenarios!

**💡 Want more examples?** Check our [**Event-Driven Governance Demo**](https://github.com/kayasax/EasyPIM-EventDriven-Governance) for production-ready automation scenarios!

---

## 📚 **Documentation & Resources**

### 📖 **Official Documentation**
- 📋 **[Complete Documentation](https://github.com/kayasax/EasyPIM/wiki/Documentation)** - In-depth guides and API reference
- 🎯 **[Use Cases & Examples](https://github.com/kayasax/EasyPIM/wiki/Use-Cases)** - Real-world implementation scenarios  
- 📝 **[Changelog](https://github.com/kayasax/EasyPIM/wiki/Changelog)** - Version history and release notes
- 🖼️ **[EasyPIM Gallery](Gallery.html)** - Visual showcase of features and capabilities

### 🚀 **Getting Started Guides**
- ⚡ **[Quick Start Tutorial](https://github.com/kayasax/EasyPIM/wiki/Getting-Started)** - First steps with EasyPIM
- 🏗️ **[Orchestrator Guide](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)** - JSON-driven workflows
- 🎛️ **[Event-Driven Demo](https://github.com/kayasax/EasyPIM-EventDriven-Governance)** - Production CI/CD automation

### 🏢 **Enterprise Resources**
- 🔧 **[Module Migration Guide](https://github.com/kayasax/EasyPIM/wiki/Module-Migration)** - Upgrade from v1.x to v2.x
- 🛡️ **[Security Best Practices](https://github.com/kayasax/EasyPIM/wiki/Security)** - Enterprise security guidelines
- 📊 **[Monitoring & Compliance](https://github.com/kayasax/EasyPIM-EventDriven-Governance/blob/main/docs/Step-by-Step-Guide.md)** - Governance frameworks

---

## 🔄 **Module Architecture & Migration** 

### 🏗️ **Two-Module Design**
| **Module** | **Purpose** | **Key Commands** |
|---|---|---|
| **EasyPIM** (Core) | Direct PIM API management | `Get-PIM*`, `Set-PIM*`, `New-PIM*` |  
| **EasyPIM.Orchestrator** | JSON-driven workflows, CI/CD | `Invoke-EasyPIMOrchestrator`, `Test-PIMPolicyDrift` |

### 📦 **Migrated Commands** (v1.x → v2.x)
These commands moved to **EasyPIM.Orchestrator** for better separation:
- `Invoke-EasyPIMOrchestrator` - JSON workflow execution
- `Test-PIMPolicyDrift` - Policy compliance monitoring  
- `Test-PIMEndpointDiscovery` - Connectivity validation

**Migration is seamless** - legacy shims provide guidance and automatic forwarding where applicable.

## 🔧 **Troubleshooting & Support**

### ⚠️ **Common Issues & Solutions**
| **Issue** | **Solution** | **Reference** |
|---|---|---|
| 🔐 **Key Vault Configuration Loading** | JSON parsing errors with configurations | [Key Vault Troubleshooting Guide](./EasyPIM/Documentation/KeyVault-Troubleshooting.md) |
| 🚫 **ARM API InvalidResourceType** | Update to latest version, verify permissions | [ARM API Guide](https://github.com/kayasax/EasyPIM/wiki/ARM-API-Troubleshooting) |
| 🔑 **Graph API Permissions** | Grant required Microsoft Graph permissions | [Permissions Guide](#-requirements) |
| 🔄 **Module Import Errors** | Version conflicts, PowerShell compatibility | [Installation Guide](#-installation) |

### 🛠️ **Diagnostic Tools**
```powershell
# Enhanced Key Vault diagnostics
Get-EasyPIMConfiguration -Verbose

# Check module versions and compatibility
Get-Module -Name EasyPIM* -ListAvailable | Select-Object Name, Version, PowerShellVersion

# Test connectivity and permissions
Test-PIMEndpointDiscovery -TenantId $tenantId  # Available in EasyPIM.Orchestrator
```

### 🆘 **Getting Help**
- 🐛 **[Report Issues](https://github.com/kayasax/EasyPIM/issues)** - Bug reports with templates
- 💬 **[Community Discussions](https://github.com/kayasax/EasyPIM/discussions)** - Q&A and feature requests  
- 📧 **[Contact Support](mailto:easypim-support@domain.com)** - Enterprise support available
- 🎯 **[Event-Driven Demo Issues](https://github.com/kayasax/EasyPIM-EventDriven-Governance/issues)** - CI/CD specific problems

---

## Contributors
- **Loïc MICHEL** - Original author and maintainer
- **Chase Dafnis** - Multi-cloud / Azure environment support

## Requirement
* Az.Accounts module
* Permission:
The PIM API for Azure resource roles is developed on top of the Azure Resource Manager framework. You will need to give consent to Azure Resource Management but won’t need any Microsoft Graph API permission. You will also need to make sure the user or the service principal calling the API has at least the Owner or User Access Administrator role on the resource you are trying to administer.
* an administrator must grant consent these permissions to the Microsoft Graph PowerShell application:
"RoleManagementPolicy.ReadWrite.Directory",
                "RoleManagement.ReadWrite.Directory",
                "RoleManagementPolicy.ReadWrite.AzureADGroup",
                "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
                "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
                "---

## 🤝 **Contributors & Community**

### 👥 **Core Contributors**
- **[Loïc MICHEL](https://github.com/kayasax)** - Original author and maintainer  
- **[Chase Dafnis](https://github.com/CHDAFNI-MSFT)** - Multi-cloud / Azure environment support

### 🌟 **Community Support**  
- ⭐ **[Star this repository](https://github.com/kayasax/EasyPIM/stargazers)** if EasyPIM helps you!
- 🐛 **[Report issues](https://github.com/kayasax/EasyPIM/issues)** to help improve the platform
- 💡 **[Feature requests](https://github.com/kayasax/EasyPIM/discussions)** for new capabilities
- 🤝 **[Contributing](CONTRIBUTING.md)** - We welcome pull requests and contributions

---

## 📋 **Requirements**

### 🖥️ **System Requirements**
- **PowerShell**: 5.1+ (Windows) or 7.0+ (Cross-platform)  
- **Modules**: `Az.Accounts`, `Microsoft.Graph.Authentication` (auto-installed)
- **Permissions**: Azure subscription access + Graph API permissions (see below)

### 🔑 **Required Permissions**

#### 🔵 **Azure Resource Roles** (ARM API)
- **Azure Subscription**: `Owner` or `User Access Administrator` role
- **Consent**: Azure Resource Manager API access (automatic)

#### 🟢 **Entra ID & Groups** (Microsoft Graph API)  
Administrator must grant these Microsoft Graph permissions:
```
• RoleManagementPolicy.ReadWrite.Directory
• RoleManagement.ReadWrite.Directory  
• RoleManagementPolicy.ReadWrite.AzureADGroup
• PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup
• PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup
• PrivilegedAccess.ReadWrite.AzureADGroup
```

### 🌍 **Multi-Cloud Support**
- ✅ **Azure Public** (default)
- ✅ **Azure Government** (`AzureUSGovernment`)  
- ✅ **Azure China** (`AzureChinaCloud`)
- ✅ **Azure Germany** (`AzureGermanCloud`)

**Thanks to [Chase Dafnis](https://github.com/CHDAFNI-MSFT) for multi-cloud support!**

---

## 📄 **License**

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

**Built with ❤️ for the Azure Administrator Community**

---
*⚡ Ready to transform your PIM management? Start with the [Event-Driven Governance Demo](https://github.com/kayasax/EasyPIM-EventDriven-Governance)!*"


