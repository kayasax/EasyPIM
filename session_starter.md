# 🧠 EasyPIM Session Starter

## 📘 Current Work Status
- ✅ **COMPLETED**: Critical drift detection scope fix in `Test-PIMPolicyDrift`
- ✅ **RESOLVED**: Telemetry issues with KeyVault configurations
- ✅ **RELEASED**: EasyPIM.Orchestrator v1.2.0 with scope validation fix
- **Status**: Production ready - critical bug fixed and released

**Recent Achievements:**
- 🚨 **Critical Fix**: Resolved scope mismatch causing false "Match" in drift detection for Azure resource policies
- 🔧 **Telemetry Enhancement**: Fixed KeyVault-based telemetry with enhanced debug output
- 📦 **Release Management**: Tagged and released orchestrator-v1.2.0 with critical fixes
- ✅ **Validation**: All 6,958 build tests passing

## 🎯 Project Overview
**EasyPIM** - PowerShell module for Microsoft Entra PIM management with two-module architecture:
- **EasyPIM** (Core): Individual PIM functions, backup/restore, policies
- **EasyPIM.Orchestrator**: Comprehensive configuration management via `Invoke-EasyPIMOrchestrator`

**Current Status**: Production ready, stable releases on PowerShell Gallery

## 🔧 Current Technical State

### Versions
- **EasyPIM Core**: v2.0.12 (stable) - Published, no changes needed
- **EasyPIM.Orchestrator**: v1.2.0 (NEW) - Critical drift detection scope fix

### Recent CI/CD Improvements
- ✅ **Gallery Version Checking**: Build scripts now fail-fast if version already exists
- ✅ **Proactive Conflict Detection**: Prevents wasted CI cycles from version conflicts
- ✅ **Systematic Reliability**: No more repeated pipeline failures

### Architecture
- **Module Split**: Core + Orchestrator with clean dependencies
- **Build Process**: Flattened modules with UTF-8 BOM, Gallery version validation
- **CI/CD**: GitHub Actions with tag-based publishing (core-v*, orchestrator-v*)

## 📅 Recent Key Updates

| Date | Update |
|------|--------|
| 2025-09-03 | **🚨 CRITICAL DRIFT DETECTION FIX**: Discovered and fixed critical bug in `Test-PIMPolicyDrift` where drift detection showed false "Match" results for Azure resource policies. Root cause: drift detection was always querying subscription-level policies while orchestrator applied resource-specific policies, causing scope validation mismatches. Fixed by implementing scope-aware policy validation in drift detection. Orchestrator bumped to v1.2.0. This resolves cases where policies like "Contributor" at storage account scopes failed to apply but drift detection incorrectly reported "Match". |
| 2025-09-03 | **Telemetry KeyVault Enhancement**: Enhanced `Send-TelemetryEventFromConfig` with improved debug output and config object validation for KeyVault-based configurations. Added fallback SHA256 identifier creation and comprehensive error handling. |
| 2025-08-31 | **Issue #136 Implementation**: Implemented policy template merge feature allowing users to specify base templates with inline property overrides. Enhanced EntraRoles.Policies, AzureRoles.Policies, and GroupRoles.Policies sections to copy non-Template properties as overrides when Template is specified. **Dependency Optimization**: Removed unnecessary `Microsoft.Graph.Identity.Governance` requirement from orchestrator module after code analysis showed it only uses `Microsoft.Graph.Authentication` cmdlets. |
| 2025-08-30 | **Issue #137**: Created branch `feature/issue-137-protected-roles-override` to implement -Force flag for overriding protected roles in orchestrator. Issue #138 confirmed resolved in v2.0.5. |
| 2025-08-29 | **CI/CD Reliability**: Added proactive Gallery version checking to prevent repeated pipeline failures. Core bumped to v2.0.5. |
| 2025-08-29 | **Documentation**: Updated Step-by-step Guide for module split architecture with installation and authentication guidance. |
| 2025-08-28 | **Stable Release**: Promoted to stable versions, removed prerelease tags. Module separation milestone achieved. |
| 2025-08-27 | **Architecture**: Module split completed with clean internal function duplication, no shared dependencies. |

## 🎯 Immediate Context

### Current Work Status
- ✅ **Completed**: Critical scope validation fix in drift detection
- ✅ **Released**: EasyPIM.Orchestrator v1.2.0 with fixes
- ✅ **Tagged**: orchestrator-v1.2.0 pushed to trigger publishing
- 📊 **Validation**: All 6,958 build tests passing

### What Just Happened
- 🚨 **Critical Discovery**: Found scope mismatch bug causing false "Match" in drift detection
- 🔧 **Root Cause**: Drift detection used subscription scope while orchestrator used resource-specific scopes
- ✅ **Solution**: Enhanced `Test-PIMPolicyDrift` with scope-aware validation
- 📦 **Release**: Bumped orchestrator to v1.2.0 and published fix

### Next Actions Available
- [ ] Monitor publishing workflow for orchestrator-v1.2.0
- [ ] Validate published module functionality
- [ ] Update documentation if needed
- [ ] Continue monitoring for any related issues

## 🧠 Assistant Memory

### **Key Technical Discoveries**

- **Critical Bug Found (Sept 3, 2025)**: Discovered scope mismatch bug in `Test-PIMPolicyDrift` causing false "Match" reports
  - **Root Cause**: Drift detection queried subscription-level policies while orchestrator applied resource-specific policies
  - **Impact**: Azure resource policies (e.g., Contributor at storage account scope) would fail to apply but drift showed "Match"
  - **Solution**: Enhanced drift detection to use policy's specific scope for validation
  - **Example**: Storage account scope `/subscriptions/.../resourceGroups/.../storageAccounts/...` now properly validated
  - **Evidence**: 400 Bad Request on policy apply vs "Match" in drift detection for same role

### **Module Architecture Understanding**

- **Two-Module System**: EasyPIM Core (individual functions) + Orchestrator (comprehensive workflows)
- **Internal Function Duplication**: Orchestrator embeds needed internal functions to avoid shared dependencies
- **Scope Handling**: Azure policies validated at specific resource scopes vs subscription defaults
- **Telemetry System**: Supports both file-based and KeyVault-based configurations with PostHog integration

### **Build & CI/CD Patterns**

- **Version Strategy**: Core module stable at v2.0.12, orchestrator v1.2.0 with critical fix
- **Publishing**: Tag-based for core (`core-v*`), manual/commit for orchestrator
- **Gallery Integration**: Proactive version checking prevents CI failures
- **Validation**: 6,958 tests must pass for release readiness

### **Security & Governance**

- **Protected Roles**: Global Admin, Security Admin blocked by default with override capability
- **Telemetry Consent**: Strict opt-in model (ALLOW_TELEMETRY: true required)
- **Audit Logging**: Policy changes logged with timestamps and change tracking
- **Scope Validation**: Different Azure resource scopes have different validation rules

### **Troubleshooting Insights**

- **False Positives**: Drift detection can give false "Match" if scope validation differs
- **ARM API Errors**: 400 Bad Request often indicates scope-specific validation failures
- **Configuration Inheritance**: Templates merge with inline overrides for policy customization
- **Authentication Context**: Auto-removes MFA requirements to prevent conflicts (MfaAndAcrsConflict)

### **Development Workflow**

- **Module Testing**: Import with explicit paths for development: `Import-Module ./EasyPIM.Orchestrator/EasyPIM.Orchestrator.psd1 -Force`
- **Build Validation**: Always run `.\build\vsts-validate.ps1` before committing
- **Version Management**: Core and orchestrator modules versioned independently
- **Release Process**: Tag-based publishing with descriptive commit messages

---

## 🔧 Technical Implementation Guide

### **Common Issues & Solutions**

| Error | Cause | Solution |
|-------|-------|----------|
| `version 'X.Y.Z' is already available` | Version already published | Bump version in manifest |
| False "Match" in drift detection | Scope mismatch between detection and application | Use scope-aware validation |
| KeyVault telemetry not working | Missing config object support | Use `Send-TelemetryEventFromConfig` |
| 400 Bad Request on policy apply | Azure scope-specific validation rules | Check policy compatibility with target scope |

### **Validation Workflow**

**Before Publishing**:
1. ✅ Run local build with `-SkipPublish` flag
2. ✅ Test module import: `Import-Module ./output/ModuleName`
3. ✅ Verify function availability: `Get-Command -Module ModuleName`
4. ✅ Check for syntax errors in generated `.psm1`
5. ✅ Validate dependencies resolve correctly

**After Publishing**:
1. ✅ Verify module appears on PowerShell Gallery
2. ✅ Test installation: `Install-Module ModuleName -Force`
3. ✅ Validate functionality in clean environment

### **GitHub Actions Integration**

**Core Module**: Tag-based publishing (`build-core-tag.yml`)
- Triggered by tags matching `core-v*` pattern
- Automatically builds and publishes to PowerShell Gallery
- Uses repository secrets for API key

**Orchestrator Module**: Tag-based publishing (`build-orchestrator.yml`)
- Triggered by tags matching `orchestrator-v*` pattern
- Automatic trigger on orchestrator file changes
- Validates dependencies before publishing

---

## 📊 Repo Snapshot (Current)

- Created: 2024-01-04 (UTC)
- Stars: 176, Forks: 15, Watchers: 176, Subscribers: 7
- Issues: 3 open / 48 closed
- Pull Requests: 0 open / 68 merged
- Contributors: 2 (kayasax, patrick-de-kruijf)
- Languages: PowerShell (~752kB), HTML (~1.6kB)
- Latest Releases: EasyPIM v2.0.12, EasyPIM.Orchestrator v1.2.0

---

*Last updated: 2025-09-03 - Critical scope validation fix completed*
