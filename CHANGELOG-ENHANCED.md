# 📋 EasyPIM Changelog

> **Latest Updates**: Protected Roles Override System, Module Architecture Split, Enhanced User Experience

---

## 🚀 **V1.0.7 Orchestrator** _(August 30, 2025)_

### 🛡️ **Major Feature: Protected Roles Override System**
- **NEW**: `-AllowProtectedRoles` parameter for `Invoke-EasyPIMOrchestrator`
  - Interactive confirmation required with `CONFIRM-PROTECTED-OVERRIDE` input
  - Enterprise-grade security controls for critical role policy changes
  - Windows Event Log integration for audit compliance

### 🎯 **Protected Roles Coverage**
- **Entra Roles**: Global Administrator, Privileged Role Administrator, Security Administrator, User Access Administrator
- **Azure Roles**: Owner, User Access Administrator

### ✨ **Enhanced User Experience**
- **WhatIf Preview Warnings**:
  - `[⚠️ PROTECTED - BLOCKED]` without -AllowProtectedRoles
  - `[⚠️ PROTECTED - OVERRIDE ENABLED]` with -AllowProtectedRoles
- **Drift Detection Visual Indicators**: `[⚠️ PROTECTED]` in `Test-PIMPolicyDrift` output
- **Consistent Visual Language**: Unified warning system across all tools

### 🏗️ **Architecture Improvements**
- **Clean Implementation**: Orchestrator-only changes, no core module modifications
- **Backward Compatibility**: No breaking changes
- **Security-First Design**: Break-glass protection with operational flexibility

---

## 🏗️ **V2.0.2 Core + V1.0.6 Orchestrator** _(August 2025)_

### 📦 **Module Architecture Split**
- **NEW**: Separated EasyPIM into two focused modules:
  - **EasyPIM Core (2.0.2)**: Core PIM management functions
  - **EasyPIM Orchestrator (1.0.6)**: Configuration-driven orchestration layer
- **Improved Maintainability**: Clean separation of concerns
- **Enhanced Testing**: Dedicated test suites for each module
- **Better Distribution**: Granular module management

### 🔧 **Core Module Enhancements**
- **Delta Mode as Default**: Safer incremental policy management
- **Enhanced Business Rules Validation**: Improved policy compliance checking
- **Refined Error Handling**: Better error messages and recovery

### 🎛️ **Orchestrator Improvements**
- **Advanced Configuration Processing**: Enhanced JSON parsing with comments support
- **Improved Assignment Lifecycle**: Better creation, validation, and cleanup flows
- **Enhanced Reporting**: Detailed operation summaries and status tracking

---

## 📈 **V1.9.4** _(Previous Release)_

### 🔧 **Orchestrator Group Policy PATCH Stability**
- Filter out null rule entries before PATCH to avoid Graph schema errors
- Re-filter during per-rule isolation after global PATCH failures
- Policy summary now correctly increments "Failed" on apply errors

---

## 🔧 **V1.9.3**

### 🐛 **Fixes**
- **Orchestrator Entra Policy Payload Corrections**: Improved policy data handling
- **Authentication Context Enhancement**: Automatically remove MFA when authentication context is specified

---

## 🔧 **V1.9.2**

### 🐛 **Fixes**
- **Copy-PIMEntraRolePolicy**: Now supports multiple role names
- **Show-PIMReport**: Properly handles empty data scenarios
- **Role Name Handling**: Role names are no longer case-sensitive

---

## 🔧 **V1.9.1**

### 🐛 **Fixes**
- **Authentication Context**: Correctly implemented in copy/export/import functions for Entra roles

---

## 🚀 **V1.9** - *Configuration-Driven PIM Management*

### 🎯 **Major Feature**
- **Invoke-EasyPIMOrchestrator**: Full policy definition from configuration files
- **Complete Coverage**: Protected accounts, policies, and assignments
- **Infrastructure as Code**: PIM assignments and policies as code

---

## 🔧 **V1.8.4.3**

### 🐛 **Fixes**
- **Issue #107**: Added missing ActiveAssignment requirements processing to import functions

---

## 🔧 **V1.8.4**

### 🐛 **Fixes**
- **Scope Validation**: Fixed Azure get-pimAzure*assignment scope validation

---

## 🔧 **V1.8.3**

### ✨ **Enhancements**
- **Graph Pagination**: Receive all results (previously limited to first 50)

---

## 🚀 **V1.8** - *PIM as Code Foundation*

### 🎯 **Major Release**
- **Invoke-EasyPIMOrchestrator**: "Your PIM assignments as code" capability
- **Configuration-Driven Management**: Declarative PIM configuration

---

## ✨ **V1.7.7**

### 🆕 **New Features**
- **Copy-PIMEntraRoleEligibleAssignment**: New cmdlet for Entra role assignment copying

---

## 🔧 **V1.7.6**

### 🐛 **Fixes**
- **Azure Assignment Removal**: Fixed "RequestCannotBeCancelled" error for provisioned assignments

---

## 🔧 **V1.7.5**

### 🐛 **Fixes**
- **PIMGroup Cmdlets**: Fixed mandatory parameter issues

---

## ✨ **V1.7.4**

### 🆕 **New Features**
- **Copy-PIMAzureResourceEligibleAssignment**: Copy Azure eligible assignments between users

---

## 🔧 **V1.7.3**

### 🐛 **Fixes**
- **Approval Configuration**: Fixed set-approval with no approvers provided

---

## 🔧 **V1.7.2**

### 🐛 **Fixes**
- **ARM Calls**: Fixed Management group scope ARM calls

---

## ✨ **V1.7.1**

### 🆕 **New Features**
- **Group Approvals**: Adding cmdlets to manage Group approvals

---

## 🚀 **V1.7** - *Approval Management*

### 🎯 **Major Feature**
- **Approval Management**: Cmdlets for Entra and Azure approvals

---

## 🔧 **V1.6.7**

### 🐛 **Fixes**
- **PowerShell 5 Compatibility**: Fixed Get-PIMEntraRolePolicy issues
- **ARM Calls**: Using Invoke-AZRestMethod for ARM calls

---

## 🔧 **V1.6.6**

### 🐛 **Fixes**
- **PowerShell 5 Compatibility**: Fixed Get-PIMGroupPolicy issues

---

## 🔧 **V1.6.5**

### 🐛 **Fixes**
- **Azure Assignment Removal**: Fixed removal with future StartDateTime

---

## 🔧 **V1.6.4**

### 🐛 **Fixes**
- **Issue #54**: Fixed authentication context claim retrieval

---

## ✨ **V1.6.3**

### 🆕 **New Features**
- **Authentication Context Support**: Added authentication context and active assignment requirements

---

## 🔧 **V1.6.2**

### ✨ **Enhancements**
- **Error Handling**: Improved error handling for non-existent role names

---

## 🔧 **V1.6.1**

### 🐛 **Fixes**
- **Show-PIMReport**: Added missing Graph scopes

---

## 🚀 **V1.6** - *PIM Reporting*

### 🎯 **Major Feature**
- **Show-PIMReport**: Visual PIM activity information from audit logs

---

## ✨ **V1.5.8**

### 🆕 **New Features**
- **Version Checker**: Added version checking capability

---

## 🔧 **V1.5.7**

### 🐛 **Fixes**
- **Exception Handling**: Fixed exception catching issues

---

## 🔧 **V1.5.6**

### 🐛 **Fixes**
- **Graph Permissions**: Fixed missing Graph permissions for groups

---

## 🔧 **V1.5.5**

### 🐛 **Fixes**
- **PowerShell 5 Compatibility**: Fixed get-PIMGroupPolicy failures

---

## 🔧 **V1.5.4**

### 🐛 **Fixes & Improvements**
- **Approvers**: Type no longer case sensitive
- **API Migration**: Using roleScheduleInstances instead of roleSchedules (future assignments visibility limitation)

---

## 🔧 **V1.5.1-1.5.3**

### 🐛 **Fixes**
- Various minor fixes and improvements

---

## 🚀 **V1.5** - *PIM Groups Support*

### 🎯 **Major Feature**
- **PIM Groups**: Full support for PIM Groups (policy + assignment)

---

## 🚀 **V1.4** - *Entra Role Assignments*

### 🎯 **Major Feature**
- **Entra Role Assignment Management**: New cmdlets for managing Entra Role assignments

---

## 🚀 **V1.3** - *Entra Role Policies*

### 🎯 **Major Features**
- **Entra Role Policy Management**:
  - `Backup-PIMEntraRolePolicy`
  - `Copy-PIMEntraRolePolicy`
  - `Export-PIMEntraRolePolicy`
  - `Get-PIMEntraRolePolicy`
  - `Import-PIMEntraRolePolicy`
  - `Set-PIMEntraRolePolicy`

---

## 🔧 **V1.2.3**

### 🐛 **Fixes**
- **Assignment Creation**: Fixed new assignment failures with scope parameter

---

## 🔧 **V1.2.2**

### 🐛 **Fixes**
- **Initialization**: Fixed uninitialized values
- **PowerShell 5**: Compatibility improvements (get-date -asUTC) - thanks to @limjianan
- **Permanent Assignments**: Fixed disallowing permanent active assignments

---

## 🔧 **V1.2.1**

### 🐛 **Fixes**
- Minor fixes

---

## 🚀 **V1.2.0** - *Azure Resource Assignments*

### 🎯 **Major Feature**
- **Azure Resource Assignment Management**: Cmdlets for PIM Azure Resource assignments

---

## ✨ **V1.1.0**

### 🆕 **New Features**
- **Scope Parameter**: Manage roles at scopes other than subscription level

---

## 🔧 **V1.0.1 & V1.0.2**

### 🐛 **Fixes**
- **Cross-Platform**: Disabled logging for non-Windows OS compatibility

---

## 🚀 **V1.0.0** - *Initial Release*

### 🎯 **Foundation**
- **PowerShell Gallery**: First release in PowerShell Gallery
- **Core PIM Functionality**: Basic PIM management capabilities

---

## 📊 **Release Statistics**

| Module | Current Version | Total Releases |
|--------|----------------|----------------|
| **EasyPIM Core** | 2.0.2 | 25+ |
| **EasyPIM Orchestrator** | 1.0.7 | 7 |
| **Combined Legacy** | 1.9.4 | 15+ |

---

## 🔗 **Quick Links**

- 📖 [Documentation](https://github.com/kayasax/EasyPIM/wiki)
- 🚀 [Getting Started](https://github.com/kayasax/EasyPIM/wiki/Invoke%E2%80%90EasyPIMOrchestrator-step%E2%80%90by%E2%80%90step-guide)
- 🐛 [Report Issues](https://github.com/kayasax/EasyPIM/issues)
- 💬 [Discussions](https://github.com/kayasax/EasyPIM/discussions)
- 📦 [PowerShell Gallery](https://www.powershellgallery.com/packages/EasyPIM)

---

## 🏷️ **Legend**

- 🚀 **Major Release**: Significant new features or architectural changes
- ✨ **New Features**: New functionality added
- 🔧 **Minor Release**: Bug fixes and small improvements
- 🐛 **Fixes**: Bug fixes and corrections
- 🛡️ **Security**: Security-related improvements
- 📦 **Architecture**: Structural or architectural changes

---

*Last Updated: August 30, 2025*
