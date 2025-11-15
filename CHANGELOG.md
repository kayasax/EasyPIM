# EasyPIM Changelog

All notable changes to the EasyPIM project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Issue #239**: MFA requirement on active assignments now properly preserved during `Copy-PIMEntraRolePolicy` operations
  - **Root Cause**: `Import-EntraRoleSettings` and `Set-ActiveAssignmentRequirement` were incorrectly filtering out `MultiFactorAuthentication` from `ActiveAssignmentRequirement` (Rule #7: `Enablement_Admin_Assignment`)
  - **Corrected Understanding**: Old code comment incorrectly stated "no MFA on Admin assignment" - Microsoft Graph API Rule #7 DOES support MFA on active assignments
  - **Fix Applied**: Added `'MultiFactorAuthentication'` to allowed admin enablement rules for Rule #7
  - **Additional Correction**: Removed `'Ticketing'` from Rule #7 allowed values - Ticketing is only supported for Rule #2 (`Enablement_EndUser_Assignment` - end-user activation), not Rule #7 (admin assignment)
  - **Rule #7 Valid Values**: `Justification`, `MultiFactorAuthentication` (per Microsoft Graph API specification)
  - **Updated Documentation**: Clarified function help to distinguish Rule #2 (activation) vs Rule #7 (active assignment)
  - **Reference**: [Microsoft Docs - PIM Rules Mapping](https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview#assignment-rules) (Rule #7: Enablement_Admin_Assignment)
  - **Impact**: Security settings now properly copied between roles; MFA requirements no longer silently dropped
  - **Testing**: Added comprehensive regression test suite with 5 test cases; verified RED→GREEN TDD cycle
  - **Reported by**: @artorro

## [EasyPIM Core 2.0.41] - 2025-11-11

### Fixed
- **Approver Type Case-Insensitivity**: Approver `Type` parameter now accepts case-insensitive values ("user"/"User", "group"/"Group"). ARM API previously rejected lowercase values with 400 Bad Request. Fixes #218.

### Enhanced
- **Documentation**: Updated all Set-PIM*Policy functions to clarify that approver Type is case-insensitive in examples and parameter descriptions.

## [EasyPIM Core 2.0.40] - 2025-11-11

### Fixed
- **Backup Resilience**: `Backup-PIMAzureResourcePolicy` now gracefully handles 404 errors when custom roles have PIM policies at child scopes (e.g., resource groups). Emits warning and continues backup instead of failing. Fixes #223.

## [EasyPIM Core 2.0.39] - 2025-11-11

### Enhanced
- **Package Metadata**: Updated ProjectUri to GitHub Pages documentation site (https://kayasax.github.io/EasyPIM/)
- **Discoverability**: Enhanced module descriptions emphasizing ease of use, automation capabilities, and overcoming portal/API limitations
- **Tags**: Added comprehensive tags for better PowerShell Gallery discovery (RBAC, Identity, Security, Governance, Compliance, ARM, Graph)

## [EasyPIM.Orchestrator 1.4.10] - 2025-11-11

### Enhanced
- **Graph Scope Optimization**: Graph authentication now only required for Entra/Group operations, not Azure-only operations. Contributed by @AzureStackNerd (PR #225).
- **Package Metadata**: Enhanced description highlighting PIM-as-Code, configuration-driven deployment, and drift detection capabilities
- **Tags**: Added PIM-as-Code, GitOps, Infrastructure-as-Code, Automation, Configuration-Management tags

## [EasyPIM Core 2.0.38] - 2025-11-11

### Fixed
- **Report Accuracy**: Fixed unique users count in PIM activity reports to use `initiatedBy` property instead of `requestor`, resolving discrepancy with top requestors display.

## [EasyPIM Core 2.0.37] - 2025-11-11

### Added
- **Report Navigation**: Added fixed sidebar navigation with jump links to report sections (Summary, Categories, Results, Activity, Requestors, Azure Roles, Entra Roles)
- **PDF Export**: Added one-click PDF export button using browser print functionality
- **Print-Friendly CSS**: Enhanced report template with print-optimized styling (page-break-inside: avoid, hidden navigation)

## [EasyPIM Core 2.0.35] - 2025-11-11

### Fixed
- **Module Loading Architecture**: Removed all internal function dot-sourcing to support build process concatenation
- **Template Path Resolution**: Fixed template path logic to work in both source and built module scenarios
- **Build Compatibility**: Ensured helper functions in `internal/functions/` auto-load without explicit dot-sourcing

## [EasyPIM Core 2.0.33] - 2025-11-11

### Fixed
- **Module Structure**: Moved internal helper functions from `internal/` to `internal/functions/` for proper auto-loading in built modules
- **Function Loading**: Resolved module import issues where internal functions were not available after publish

## [EasyPIM Core 2.0.32] - 2025-11-11

### Added
- **Report Branding**: Added EasyPIM logo display in report header and footer with brightness enhancement for dark backgrounds
- **Date Range Display**: Added date filtering information when StartDate/EndDate parameters used in reports

### Fixed
- **Documentation URLs**: Corrected all documentation links to point to GitHub Pages site
- **Code Quality**: Achieved 100% PSScriptAnalyzer compliance (7,018 tests passing)
- **Unused Code Cleanup**: Removed ~94 lines of unused variables from pre-refactor code in Show-PIMReport

## [EasyPIM Core 2.0.31] - 2025-10-11

### Fixed
- Restored Administrative Unit scope support for `Remove-PIMEntraRoleActiveAssignment` and `Remove-PIMEntraRoleEligibleAssignment` by honoring the provided `Scope` (tenant, GUID, display name, or full path) when building removal requests.

## [EasyPIM Core 2.0.30] - 2025-10-11

### Fixed
- Hardened `Test-PIMPolicyBusinessRules` to strip conflicting AuthenticationContext entries from activation requirement arrays.
- Updated `Test-EasyPIMConfigurationValidity` to surface invalid activation requirements before deployment and align template normalization with runtime behavior.

### Improved
- Assignment validation now requires both scope and role when checking existing Azure entries, preventing status strings from blocking new assignments.

## [EasyPIM.Orchestrator 1.4.9] - 2025-10-13

### Added
- `Invoke-EasyPIMOrchestrator` now supports `-ProtectedRoleOverrideToken`, enabling CI pipelines to acknowledge protected-role policy updates without interactive prompts.

### Improved
- Startup/completion telemetry records whether the override token was provided, giving auditors visibility into protected-role automation runs.
- Added Pester coverage ensuring the override token path bypasses `Read-Host` only with the correct confirmation value.

## [EasyPIM.Orchestrator 1.4.8] - 2025-10-13

### Fixed
- `Set-EPOEntraRolePolicy` now permanently bypasses Global Administrator policy automation with explicit safety messaging and manual-management guidance.

### Improved
- `Invoke-EasyPIMOrchestrator` highlights Global Administrator policy entries during runs so operators know they remain untouched as break-glass roles.
- Added targeted unit coverage to guard protected-role override behavior against regressions.

## [EasyPIM.Orchestrator 1.4.7] - 2025-10-11

### Fixed
- Azure assignment pre-checks ignore status-only strings and enforce scope + role matches before skipping creations.
- `Test-EasyPIMConfigurationValidity` removes stray AuthenticationContext activation requirements that would fail during deployment.

### Changed
- `Test-PIMPolicyDrift` reuses orchestrator normalization when available so drift detection mirrors live execution.

## [EasyPIM.Orchestrator 1.4.5] - 2025-10-08

### Added
- Support array-based policy definitions for Azure, Entra, and group roles with template override handling.
- Added dedicated documentation and sample configuration for the new array-based policy format.

### Fixed
- `Test-PIMPolicyDrift` now compares template-based policies using the resolved policy payload generated by the orchestrator, restoring drift accuracy.
- Removed trailing whitespace flagged by FileIntegrity tests to keep module validation clean.

## [EasyPIM.Orchestrator 1.2.0] - 2025-09-03

### 🚨 Critical
- **FIXED**: Critical scope mismatch bug in `Test-PIMPolicyDrift` causing false "Match" results
- **SECURITY**: Scope validation now matches policy application behavior preventing false positives

### Fixed
- Fixed drift detection always using subscription scope instead of policy-specific scopes
- Enhanced `Test-PIMPolicyDrift` to use scope-aware policy validation
- Added verbose logging to show which scope is being used for drift detection
- Resolved cases where Azure resource policies failed to apply but drift showed "Match"

### Enhanced
- Improved debug output in telemetry functions
- Enhanced KeyVault configuration support in telemetry

### Technical Details
- **Root Cause**: Drift detection queried subscription-level policies while orchestrator applied resource-specific policies
- **Impact**: Azure resource policies (e.g., Contributor at storage account scope) would fail but appear correctly configured
- **Solution**: Enhanced drift detection to validate at the same scope as policy application
- **Evidence**: 400 Bad Request on policy apply vs "Match" in drift detection for same role

## [EasyPIM.Orchestrator 1.1.9] - 2025-09-03

### Fixed
- Fixed telemetry variable name bugs preventing KeyVault configuration telemetry
- Corrected `$loadedConfig` to `$config` variable references in orchestrator
- Enhanced telemetry functions with SHA256 fallback identifier creation
- Improved debug output for telemetry troubleshooting

### Enhanced
- Added `Send-TelemetryEventFromConfig` function for config object-based telemetry
- Enhanced error handling in telemetry functions with non-blocking fallbacks
- Added color-coded debug messages for better troubleshooting

## [EasyPIM Core 2.0.12] - 2025-09-03

### Fixed
- Fixed corrupted `Invoke-ARM.ps1` file with duplicate code blocks
- Removed duplicate try-catch sections and extra closing braces
- Resolved PowerShell parser errors in CI/CD environments

### Validation
- All 6,973+ tests now pass successfully
- Complete build validation restored

## [EasyPIM.Orchestrator 1.1.8] - 2025-08-31

### Added
- Policy template merge feature with inline property overrides
- Support for base templates with custom property modifications
- Enhanced EntraRoles.Policies, AzureRoles.Policies, and GroupRoles.Policies sections

### Changed
- Removed unnecessary `Microsoft.Graph.Identity.Governance` dependency
- Optimized module dependencies after code analysis
- Updated to use only `Microsoft.Graph.Authentication` cmdlets

### Enhanced
- Template resolution with non-Template property copying as overrides
- Improved dependency management and module loading

## [EasyPIM Core 2.0.11] - 2025-09-02

### Added
- Proactive PowerShell Gallery version checking
- Build script fail-fast for existing versions
- Systematic CI/CD reliability improvements

### Changed
- Enhanced build process to prevent version conflicts
- Improved error handling in publishing workflow

### Fixed
- Prevented repeated pipeline failures from version conflicts
- Reduced wasted CI cycles through early validation

## [EasyPIM 2.0.x Series] - 2025-08-27 to 2025-08-29

### Major Changes
- **Architecture**: Complete module separation into Core + Orchestrator
- **Dependencies**: Clean internal function duplication, no shared dependencies
- **Publishing**: Independent versioning and release cycles
- **Documentation**: Updated guides for two-module architecture

### Added
- EasyPIM.Orchestrator as standalone module
- Tag-based publishing (core-v*, orchestrator-v*)
- Comprehensive policy orchestration system
- Enterprise-grade reliability features

### Enhanced
- Flattened module structure with UTF-8 BOM support
- Gallery version validation in build process
- Improved CI/CD workflows with GitHub Actions

---

## Version History Summary

### EasyPIM Core Releases
- **v2.0.12** (2025-09-03): Syntax fixes, build validation restored
- **v2.0.11** (2025-09-02): Gallery version checking, CI reliability
- **v2.0.10** (2025-09-02): Stable release, module separation complete
- **v2.0.x** (2025-08-27): Module split architecture implementation

### EasyPIM.Orchestrator Releases
- **v1.2.0** (2025-09-03): 🚨 Critical scope validation fix
- **v1.1.9** (2025-09-03): Telemetry KeyVault fixes, variable corrections
- **v1.1.8** (2025-08-31): Template merge feature, dependency optimization
- **v1.1.7** (2025-08-30): ARM authentication improvements
- **v1.0.x** (2025-08-27): Initial standalone orchestrator release

---

## Critical Issues Resolved

### Security & Reliability
- **Scope Validation**: Fixed false "Match" in drift detection (v1.2.0)
- **Telemetry Privacy**: Enhanced KeyVault support with proper consent validation (v1.1.9)
- **Build Reliability**: Eliminated CI failures from version conflicts (v2.0.11)
- **Syntax Errors**: Resolved PowerShell parser issues in CI environments (v2.0.12)

### Architecture & Performance
- **Module Separation**: Clean dependency structure prevents conflicts
- **Internal Functions**: Embedded approach eliminates shared dependencies
- **Publishing**: Tag-based workflows enable independent release cycles
- **Validation**: Comprehensive test suite (6,900+ tests) ensures reliability

---

*For detailed technical information and migration guides, see individual release notes in the `/publish/` directory.*
