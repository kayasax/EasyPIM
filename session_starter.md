# EasyPIM Session Starter

## 🚨 **CRITICAL TAG FORMAT REQUIREMENTS** 🚨

# ⚠️ **DO NOT FORGET TAG FORMATS!!!** ⚠️

### **EasyPIM Core Module Tags:**
```
core-vX.Y.Z
```
**Examples:** `core-v2.0.19`, `core-v2.1.0`

### **EasyPIM Orchestrator Module Tags:**
```
orchestrator-vX.Y.Z
```
**Examples:** `orchestrator-v1.3.4`, `orchestrator-v1.4.0`

### **GitHub Actions Triggers:**
- **core-v*** triggers `build-core-tag.yml` workflow
- **orchestrator-v*** triggers `build-orchestrator.yml` workflow
- **v*** (without prefix) triggers `build.yml` but is DEPRECATED - use core-v instead!

## ⚠️ **NEVER USE PLAIN v* TAGS FOR CORE MODULE!** ⚠️

---

## 🧠 **Assistant Memory & Context**

### **Current State (2025-09-09)**
- **EasyPIM Core**: v2.0.26 (preparing to tag as `core-v2.0.26`) 🚀 PENDING  
- **EasyPIM.Orchestrator**: v1.4.3 (preparing to tag as `orchestrator-v1.4.3`) 🚀 PENDING
- **Branch**: `main` (hotfix merged and published)
- **Major Bug**: ✅ RESOLVED - ARM API userType auto-detection implemented

### **🔥 CRITICAL BUG DISCOVERED & FIXED**
**Root Cause**: The orchestrator was passing approver objects in config format `{id, description}` but `Set-PIMAzureResourcePolicy` expects ARM API format `{Id, Name, Type}`. This caused 400 Bad Request errors whenever approval was required.

**Solution**: Added proper format conversion in `Set-EPOAzureRolePolicy.ps1` to map:
- `id` → `Id`
- `description` → `Name`
- Added `Type='user'` default

**Impact**: Fixes all GitHub Actions failures for approval policies (Contributor role, etc.)

### **Key Technical Achievements**
- ✅ **Critical Bug Fixed**: Approver format conversion preventing ARM API 400 errors
- ✅ **Root Cause Identified**: Config {id, description} vs ARM API {Id, Name, Type} mismatch
- ✅ **Regex-based GUID Validation**: Extracts and validates ALL principals before API calls
- ✅ **Business Rules Engine**: Handles MFA/Authentication Context conflicts automatically
- ✅ **Early Error Detection**: Clear messages instead of mysterious API failures
- ✅ **Performance Optimized**: HashSet-based validation with scope filtering

### **Module Architecture**
- **EasyPIM Core**: Individual PIM functions, backup/restore, basic policies
- **EasyPIM.Orchestrator**: Configuration management via `Invoke-EasyPIMOrchestrator`
- **Key Function**: `Test-PIMPolicyBusinessRules` for conflict resolution
- **Validation Flow**: Principal validation → Policy processing → Assignment operations

### **Publishing Workflow**
1. Bump versions in `.psd1` files
2. Create correct tags: `core-vX.Y.Z` and `orchestrator-vX.Y.Z`
3. Push tags to trigger GitHub Actions
4. Monitor PowerShell Gallery publication

---

## 🎯 **Project Overview**

**EasyPIM** - PowerShell module for Microsoft Entra PIM management with two-module architecture

### **Key Functions to Remember**
- `Invoke-EasyPIMOrchestrator`: Main orchestration function
- `Test-PIMPolicyBusinessRules`: Handles policy conflicts
- `Get-EasyPIMConfiguration`: Loads from file or Key Vault (in Orchestrator module)
- `Test-PrincipalExists`: Validates principal existence

### **Testing**
- Run `.\tests\pester.ps1 -TestGeneral $true -TestFunctions $false -Output Normal -Fast`
- All 7011+ tests should pass
- General tests cover file integrity, manifests, PSScriptAnalyzer

### **Common Issues**
- **400 Bad Request**: Usually invalid principal IDs → now caught by validation
- **MFA vs Auth Context**: Conflicts automatically resolved by business rules
- **Module Loading**: Always force reload after changes: `Import-Module -Force`

---

## 📅 **Recent Session Log**

| Date | Key Achievement |
|------|-----------------|
| 2025-09-09 | ✅ **PS5.1 COMPATIBILITY**: Fixed Unicode emoji parsing, ARM SecureString conversion, principal validation, and Graph API body handling |
| 2025-09-08 | 🔥 **MAJOR BREAKTHROUGH**: Discovered & fixed orchestrator hardcoding "Type=user" preventing auto-detection |
| 2025-09-08 | ✅ **PR CREATED**: Drift detection boolean comparison fix (false positives resolved) |
| 2025-09-08 | ✅ **VALIDATED**: Test-PIMPolicyDrift now shows 12/12 policies match (zero drift) |
| 2025-09-08 | ✅ **RELEASED**: EasyPIM Core v2.0.24, Orchestrator v1.4.0 with critical ARM API fixes |
| 2025-09-08 | ✅ **ROOT CAUSE**: Line 115 in Set-EPOAzureRolePolicy.ps1 was bypassing auto-detection logic |
| 2025-09-08 | ✅ **RELEASE**: ARM API userType auto-detection fix published (core-v2.0.21, orchestrator-v1.3.6) |
| 2025-09-08 | ✅ PR merged: Hotfix for GitHub Actions ARM API 400 Bad Request errors |
| 2025-09-07 | ✅ Principal validation prevents 400 Bad Request errors |
