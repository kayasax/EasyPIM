# EasyPIM## 📅 Session Update Log

| Date | Summary |
|------|---------|
| 2025-09-07 | **TAGS CREATED**: Published v2.0.19 (EasyPIM) and orchestrator-v1.3.4 (EasyPIM.Orchestrator) with principal validation |
| 2025-09-07 | **PRINCIPAL VALIDATION FIX**: Implemented comprehensive regex-based GUID validation to prevent 400 Bad Request errors |
| 2025-09-07 | Bumped EasyPIM to v2.0.19 and EasyPIM.Orchestrator to v1.3.4 with principal validation and business rules |
| 2025-09-07 | **ROOT CAUSE RESOLVED**: Invalid principal IDs cause ARM API 400 Bad Request - now caught early with clear errors |
| 2025-09-07 | Added business rules validation to strip MFA when Authentication Context enabled (policy conflicts) |
| 2025-09-07 | **ARCHITECTURAL FIX**: Moved Get-EasyPIMConfiguration from core to orchestrator module where it belongs |
| 2025-09-07 | Tagged and published EasyPIM v2.0.18 (architecture fix) and EasyPIM.Orchestrator v1.3.0 (enhanced config) |
| 2025-09-07 | Enhanced Key Vault error handling now properly located in orchestrator module |
| 2025-01-07 | Created local test workflow for enhanced Key Vault error handling validation (no Azure deps) |
| 2025-01-07 | Added enhanced Key Vault error handling with retry logic for CI/CD reliability in v2.0.17 |
| 2025-01-07 | Fixed JSON parsing error diagnostics for GitHub Actions troubleshooting |
| 2025-01-07 | Removed duplicate Test-EasyPIMKeyVaultSecret from public functions folder |
| 2025-01-07 | All tests passing (7061/7061) after function cleanup and error handling improvements |
| 2025-01-07 | **NOTE**: OIDC for Azure Key Vault access configured for different repo - using local testing approach |

## 🚀 Latest Release: Principal Validation & Business Rules (v2.0.19 / v1.3.4)

**Major Achievement**: Resolved root cause of 400 Bad Request errors in GitHub Actions CI/CD pipeline

### Key Features Added:
- ✅ **Comprehensive Principal Validation**: Regex-based GUID extraction validates ALL principals before ARM API calls
- ✅ **Business Rules Engine**: Automatic MFA/Authentication Context conflict resolution 
- ✅ **Early Error Detection**: Invalid principal IDs like `00000000-0000-0000-0000-000000000000` caught immediately
- ✅ **Performance Optimized**: Uses HashSet for uniqueness, validates all principals in one efficient pass
- ✅ **Scope-Aware**: Intelligently excludes subscription/management group GUIDs from principal validation
- ✅ **Clear Error Messages**: Shows exactly which principal IDs are invalid with specific details

### Root Cause Resolution:
The GitHub Actions failures were caused by invalid principal IDs in approver configurations. The new validation:
1. **Extracts ALL GUIDs** from configuration using regex pattern matching
2. **Filters out scope GUIDs** (subscriptions, management groups) to focus on principals  
3. **Validates principal existence** using Microsoft Graph API before any policy operations
4. **Aborts early** with clear error messages when invalid principals detected
5. **Prevents 400 Bad Request** errors by catching configuration issues before ARM API calls

**Technical Impact**: GitHub Actions CI/CD now fails fast with clear error messages instead of mysterious 400 Bad Request errors, making configuration issues immediately apparent and easily fixable.

### 🚀 **PUBLISHED VERSIONS**
- **EasyPIM v2.0.19**: Tagged and published to PowerShell Gallery
- **EasyPIM.Orchestrator v1.3.4**: Tagged and published to PowerShell Gallery
- **GitHub Actions**: Publishing workflows triggered automatically

## 📘 Current Work Status
- ✅ **ARCHITECTURAL FIX**: Get-EasyPIMConfiguration moved to proper module location
- ✅ **Core Module**: v2.0.18 with cleaner architecture (removed config function)
- ✅ **Orchestrator Module**: v1.3.0 with enhanced Key Vault error handling + config function
- 🚀 **PUBLISHING**: Both v2.0.18 and v1.3.0 tags pushed, GitHub Actions publishing in progress
- **Current Gallery State**: Will be EasyPIM v2.0.18, EasyPIM.Orchestrator v1.3.0

**Recent Local Enhancements (NOT YET PUBLISHED):**
- 🔧 **Enhanced Key Vault Handling**: Retry logic for CI/CD reliability, improved JSON parsing error diagnostics
- 🧹 **Function Cleanup**: Removed duplicate Test-EasyPIMKeyVaultSecret from public functions
- � **Better Error Messages**: Detailed JSON parsing error diagnostics for GitHub Actions troubleshooting
- 🔄 **Retry Logic**: Key Vault secret retrieval with automatic retry for transient failures
- 🛡️ **Cross-Platform Compatibility**: Enhanced error handling for PowerShell Core vs Windows PowerShell differences

## 🎯 Project Overview
**EasyPIM** - PowerShell module for Microsoft Entra PIM management with two-module architecture:
- **EasyPIM** (Core): Individual PIM functions, backup/restore, policies
- **EasyPIM.Orchestrator**: Comprehensive configuration management via `Invoke-EasyPIMOrchestrator`

**Current Status**: Production ready, stable releases on PowerShell Gallery

## 🔧 Current Technical State

### Versions
- **EasyPIM Core**:
  - **Local**: v2.0.18 (Architecture fix - removed config function, enhanced module separation)
  - **PowerShell Gallery**: v2.0.18 🚀 **PUBLISHING IN PROGRESS**
- **EasyPIM.Orchestrator**:
  - **Local**: v1.3.0 (Enhanced Key Vault error handling + proper config function ownership)
  - **PowerShell Gallery**: v1.3.0 🚀 **PUBLISHING IN PROGRESS**

### 🚨 Publishing Action Required
- **core-v2.0.15**: Key Vault troubleshooting enhancements + secret version output ✅ **TAGGED & PUSHED**
- **core-v2.0.16**: PSScriptAnalyzer compliance + code quality fixes ✅ **TAGGED & PUSHED**
- **orchestrator-v1.2.3**: Configuration validation dot-sourcing fix ✅ **TAGGED & PUSHED**
- **orchestrator-v1.2.5**: Critical PSM1 flattening build fix ✅ **TAGGED & PUSHED**
- **Status**: All correct tags pushed to origin, GitHub Actions should auto-publish to PowerShell Gallery
- **Monitor**: Check [GitHub Actions](https://github.com/kayasax/EasyPIM/actions) for publishing status

### 📦 Publishing Commands (Automated via GitHub Actions)
```powershell
# The GitHub Actions workflow publishes automatically when tags are pushed
# Tags v2.0.15 and v2.0.16 are already created locally, just need to push them

# Check local tags
git tag --list --sort=-version:refname | Select-Object -First 5

# Push the tags to trigger publishing workflow
git push origin core-v2.0.15  # ✅ Now pushed with correct format
git push origin core-v2.0.16  # ✅ Now pushed with correct format

# Verify workflow triggered on GitHub:
# https://github.com/kayasax/EasyPIM/actions

# Verify publication after workflow completes
Find-Module EasyPIM -Repository PSGallery | Select-Object Name, Version
```

### 🔧 Manual Publishing (Alternative)
```powershell
# If GitHub Actions fails, manual publishing:
git checkout v2.0.15
Publish-Module -Path ".\EasyPIM" -NuGetApiKey $env:NUGET_API_KEY -Verbose

git checkout main
Publish-Module -Path ".\EasyPIM" -NuGetApiKey $env:NUGET_API_KEY -Verbose
```

### 🔍 Troubleshooting Publishing
- **Correct Tag Format**: Use `core-v*` for EasyPIM Core, `orchestrator-v*` for Orchestrator
- **Wrong Tags**: `v*` format will NOT trigger GitHub Actions workflow
- **GitHub Actions Not Triggered**: Verify correct tags are pushed with `git ls-remote --tags origin`
- **Workflow Failed**: Check [Actions tab](https://github.com/kayasax/EasyPIM/actions) for error details
- **Gallery Delay**: PowerShell Gallery can take 15-30 minutes to index new versions
- **Version Check**: Use `Find-Module EasyPIM -AllVersions` to see all published versions

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
| 2025-09-07 | **🚨 ORCHESTRATOR BUG FIX**: Fixed critical error in orchestrator v1.2.3 where configuration validation failed with 'The term C:\Program Files\PowerShell\Modules\...' error when running from PowerShell Gallery installation. **Root Cause**: Manual dot-sourcing of internal functions conflicted with module loading. **Solution**: Removed redundant dot-sourcing as internal functions are automatically loaded by PSM1. **Impact**: Orchestrator now works correctly from Gallery installations. Tagged orchestrator-v1.2.3 and pushed for publishing. |
| 2025-09-06 | **🚨 VERSION SYNC ISSUE**: Local repository is 2 versions ahead of PowerShell Gallery. **Local**: v2.0.16 with Key Vault troubleshooting enhancements (v2.0.15) and PSScriptAnalyzer compliance (v2.0.16). **Gallery**: v2.0.14. **ACTION REQUIRED**: Publish v2.0.15 and v2.0.16 to PowerShell Gallery to sync versions. Created tags and commits but not published. All 7034 tests passing with full code quality compliance. |
| 2025-01-24 | **🔍 CONFIGURATION VALIDATION SYSTEM**: Implemented comprehensive configuration validation system to prevent ARM API failures. Created `Test-EasyPIMConfigurationValidity.ps1` with auto-correction for field name mismatches (id→Id, description→Name), missing approvers detection, and template reference validation. Integrated into orchestrator pipeline with user-friendly error reporting. This prevents the ARM API 400 Bad Request errors caused by configuration format issues and improves overall user experience. |
| 2025-09-03 | **🚨 CRITICAL DRIFT DETECTION FIX**: Discovered and fixed critical bug in `Test-PIMPolicyDrift` where drift detection showed false "Match" results for Azure resource policies. Root cause: drift detection was always querying subscription-level policies while orchestrator applied resource-specific policies, causing scope validation mismatches. Fixed by implementing scope-aware policy validation in drift detection. Orchestrator bumped to v1.2.0. This resolves cases where policies like "Contributor" at storage account scopes failed to apply but drift detection incorrectly reported "Match". |
| 2025-09-03 | **Telemetry KeyVault Enhancement**: Enhanced `Send-TelemetryEventFromConfig` with improved debug output and config object validation for KeyVault-based configurations. Added fallback SHA256 identifier creation and comprehensive error handling. |
| 2025-08-31 | **Issue #136 Implementation**: Implemented policy template merge feature allowing users to specify base templates with inline property overrides. Enhanced EntraRoles.Policies, AzureRoles.Policies, and GroupRoles.Policies sections to copy non-Template properties as overrides when Template is specified. **Dependency Optimization**: Removed unnecessary `Microsoft.Graph.Identity.Governance` requirement from orchestrator module after code analysis showed it only uses `Microsoft.Graph.Authentication` cmdlets. |
| 2025-08-30 | **Issue #137**: Created branch `feature/issue-137-protected-roles-override` to implement -Force flag for overriding protected roles in orchestrator. Issue #138 confirmed resolved in v2.0.5. |
| 2025-08-29 | **CI/CD Reliability**: Added proactive Gallery version checking to prevent repeated pipeline failures. Core bumped to v2.0.5. |
| 2025-08-29 | **Documentation**: Updated Step-by-step Guide for module split architecture with installation and authentication guidance. |
| 2025-08-28 | **Stable Release**: Promoted to stable versions, removed prerelease tags. Module separation milestone achieved. |
| Date | Update |
|------|--------|
| 2025-01-24 | **🔧 CRITICAL KEY VAULT COMPATIBILITY FIX**: Released EasyPIM Core v2.0.13 with comprehensive Key Vault secret retrieval fix. Implemented robust multi-method compatibility (SecretValueText → ConvertFrom-SecureString → Marshal) to resolve "Unexpected end when reading JSON" errors across diverse PowerShell and Azure environments. Added Az.KeyVault version detection, comprehensive error handling, and detailed logging. This resolves Key Vault retrieval failures that prevented configuration loading in production environments. |
| 2025-01-24 | **🔍 CONFIGURATION VALIDATION SYSTEM**: Released EasyPIM.Orchestrator v1.2.1 with comprehensive configuration validation system. Created `Test-EasyPIMConfigurationValidity.ps1` with auto-correction for field name mismatches (id→Id, description→Name), missing approvers detection, and template reference validation. Integrated into orchestrator pipeline with user-friendly error reporting. This prevents ARM API 400 Bad Request errors caused by configuration format issues and improves overall user experience. |
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
- ✅ **Released**: EasyPIM Core v2.0.13 with critical Key Vault compatibility fix
- ✅ **Released**: EasyPIM.Orchestrator v1.2.1 with configuration validation system
- ✅ **Tagged**: Both core-v2.0.13 and orchestrator-v1.2.1 tagged and pushed
- 📊 **Validation**: All 6,964 build tests passing

### What Just Happened
- 🔧 **Key Vault Resolution**: Fixed critical Key Vault secret retrieval compatibility issues across environments
- � **Validation System**: Implemented comprehensive configuration validation with auto-correction
- 🛡️ **Error Prevention**: Added proactive ARM API 400 error prevention through field name validation
- 📦 **Production Release**: Both modules version-bumped, tagged, and ready for PowerShell Gallery

### Next Actions Available
- [ ] Monitor PowerShell Gallery publishing for both modules
- [ ] Test Key Vault fix in production environment
- [ ] Validate configuration validation system effectiveness
- [ ] Gather user feedback on new features

## 🧠 Assistant Memory

### **Key Technical Discoveries**

- **Key Vault Compatibility Issue (Jan 24, 2025)**: Resolved critical Key Vault secret retrieval failures
  - **Root Cause**: Az.KeyVault module compatibility issues with `ConvertFrom-SecureString -AsPlainText` returning empty strings
  - **Impact**: Configuration loading failed with "Unexpected end when reading JSON" errors
  - **Solution**: Implemented robust multi-method approach with comprehensive fallbacks and error handling
  - **Methods**: SecretValueText (older versions) → ConvertFrom-SecureString (newer versions) → Marshal (maximum compatibility)

- **Configuration Validation System (Jan 24, 2025)**: Proactive error prevention for ARM API issues
  - **Purpose**: Prevent ARM API 400 Bad Request errors through configuration validation
  - **Features**: Field name mapping (id→Id, description→Name), template validation, missing approvers detection
  - **Integration**: Built into orchestrator pipeline with user-friendly error reporting and auto-correction
  - **Impact**: Eliminates common configuration errors before they reach ARM API

- **Critical Bug Found (Sept 3, 2025)**: Discovered scope mismatch bug in `Test-PIMPolicyDrift` causing false "Match" reports
  - **Root Cause**: Drift detection queried subscription-level policies while orchestrator applied resource-specific policies
  - **Impact**: Azure resource policies (e.g., Contributor at storage account scope) would fail to apply but drift showed "Match"
  - **Solution**: Enhanced drift detection to use policy's specific scope for validation
  - **Evidence**: 400 Bad Request on policy apply vs "Match" in drift detection for same role

### **Module Architecture Understanding**

- **Two-Module System**: EasyPIM Core (individual functions) + Orchestrator (comprehensive workflows)
- **Internal Function Duplication**: Orchestrator embeds needed internal functions to avoid shared dependencies
- **Scope Handling**: Azure policies validated at specific resource scopes vs subscription defaults
- **Telemetry System**: Supports both file-based and KeyVault-based configurations with PostHog integration
- **Configuration Validation**: Comprehensive validation system with auto-correction for common format issues

### **Configuration Validation System**

- **Purpose**: Prevent ARM API 400 errors through proactive configuration validation
- **Auto-Correction**: Fixes field name mismatches (id→Id, description→Name, desc→Name)
- **Validation Categories**: Field mappings, missing approvers, invalid template references
- **Integration**: Built into orchestrator pipeline with user-friendly error reporting
- **Error Prevention**: Catches configuration issues before ARM API calls

### **Build & CI/CD Patterns**

- **Version Strategy**: Core v2.0.16 (ready), orchestrator v1.2.4 (ready) with critical fixes
- **Publishing**: Tag-based for core (`core-v*`), tag-based for orchestrator (`orchestrator-v*`)
- **Gallery Integration**: Proactive version checking prevents CI failures
- **Validation**: 7,034 tests must pass for release readiness

### **Orchestrator Module Fixes (v1.2.3 → v1.2.4)**

- **Issue**: `Test-EasyPIMConfigurationValidity` function not found after PowerShell Gallery installation
- **Root Cause**: Redundant dot-sourcing line conflicted with PSM1 auto-loading in Gallery installations
- **Solution**: Removed manual dot-sourcing at line 190, rely on module scope function loading
- **Secondary Issue**: GitHub workflow installing obsolete EasyPIM v2.0.2 causing module loading failures at line 4557
- **Workflow Fix**: Updated CI/CD to install latest EasyPIM core instead of hardcoded v2.0.2
- **Impact**: Fixes PowerShell Gallery installation of orchestrator for end users
- **Testing**: Tagged orchestrator-v1.2.4 to validate workflow compatibility fix

### **Security & Governance**

- **Protected Roles**: Global Admin, Security Admin blocked by default with override capability
- **Telemetry Consent**: Strict opt-in model (ALLOW_TELEMETRY: true required)
- **Audit Logging**: Policy changes logged with timestamps and change tracking
- **Scope Validation**: Different Azure resource scopes have different validation rules

### **Troubleshooting Insights**

- **Key Vault Issues**: Use robust multi-method retrieval (SecretValueText → ConvertFrom-SecureString → Marshal)
- **Configuration Errors**: Leverage `Test-EasyPIMConfigurationValidity` for proactive validation and auto-correction
- **ARM API Errors**: 400 Bad Request often indicates field name mismatches (id→Id, description→Name) or scope issues
- **False Positives**: Drift detection can give false "Match" if scope validation differs
- **Configuration Inheritance**: Templates merge with inline overrides for policy customization
- **Authentication Context**: Auto-removes MFA requirements to prevent conflicts (MfaAndAcrsConflict)
- **Configuration Issues**: Use `Test-EasyPIMConfigurationValidity` for proactive error detection

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
- Latest Releases: EasyPIM v2.0.14, EasyPIM.Orchestrator v1.2.2 (ready for publishing)

**Project Context Awareness**

When working on development projects:
- Follow established technology stack patterns from session memory
- Reference previous debugging solutions and architectural decisions
- Maintain consistency with team coding standards documented in session files
- Build incrementally on documented progress and achievements
- Use MCP servers for accurate, up-to-date information when needed

**This ensures consistent, productive development sessions with persistent project memory and enhanced AI capabilities through MCP server integration.**

---

## 📋 Session Update Log

| Date | Summary |
|------|---------|
| 2025-09-03 | Critical scope validation fix completed |
| 2025-09-06 | ✅ **Orchestrator Fix Complete**: Fixed PowerShell Gallery installation error by removing redundant dot-sourcing (v1.2.3) and GitHub workflow version compatibility (v1.2.4). Updated CI/CD to use latest EasyPIM core instead of obsolete v2.0.2. Both fixes tagged and ready for publication. |
| 2025-09-07 | 🔧 **Critical Build Fix**: Root cause was PSM1 flattening process - regex failed to extract multiline Export-ModuleMember, creating modules with no function exports. Fixed multiline regex extraction (v1.2.5). Orchestrator should now work correctly from PowerShell Gallery. |

*Last updated: 2025-09-07 - Critical orchestrator PSM1 flattening build fix completed*
