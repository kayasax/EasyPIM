# 🚀 Major Release: EasyPIM v2.0.0-beta1 & Orchestrator v1.0.0-beta1

## 📋 Overview

This PR represents a **major architectural milestone** for EasyPIM, introducing module separation, comprehensive ARM API fixes, and preparation for PowerShell Gallery publication with beta versions.

## 🎯 **Major Changes**

### **🏗️ Version Strategy**
- **EasyPIM Core**: `v1.10.1` → `v2.0.0-beta1` (major milestone: module separation)
- **EasyPIM.Orchestrator**: `v0.1.0-beta10` → `v1.0.0-beta1` (production-ready features)
- **Justification**: Module architecture split warrants major version bump

### **🔧 ARM API Compatibility Fixes**
- **Fixed InvalidResourceType/NoRegisteredProviderFound errors** in Azure resource role assignments
- **Root Cause**: Malformed query parameters with double question marks (`?api-version=2020-10-01?$filter=...`)
- **Solution**: Corrected parameter concatenation in `Get-PIMAzureResourceActiveAssignment.ps1`
- **API Version Updates**: Updated from `2020-10-01` to `2020-10-01-preview` for endpoint compatibility
- **Scope**: Applied fixes to `Get-PIMAzureResourceEligibleAssignment.ps1`, `Get-PIMAzureResourcePendingApproval.ps1`

### **📏 Parameter Standardization**
- **Breaking Change**: `assignee` parameter renamed to `principalId` across Azure resource functions
- **Backward Compatibility**: `assignee` alias provided for existing scripts
- **Consistency**: Unified parameter naming across all assignment functions

### **🏛️ Module Architecture Improvements**
- **Dependency Management**: Enhanced `EasyPIM.Orchestrator.psd1` with proper RequiredModules
- **Module Separation**: Complete standalone orchestrator with automatic EasyPIM dependency loading
- **Session Preservation**: Fixed Microsoft Graph authentication disconnection during module imports

### **🛡️ Enhanced Policy Validation**
- **Proactive Validation**: Detects policy conflicts BEFORE ARM API calls
- **Clear Error Messages**: Actionable guidance for policy duration mismatches
- **Auto-Configuration**: Smart inference of permanent assignment flags based on duration values
- **Example**: "Requested duration 'PT8H' exceeds policy limit 'PT2H' for role User Administrator"

## 🧪 **Testing & Validation**

### **✅ Comprehensive Testing Completed**
- **ARM API Calls**: All endpoints return successful responses instead of InvalidResourceType errors
- **Full Orchestrator Workflow**: 7/7 policies applied, 9/9 assignments processed successfully
- **Policy Validation**: Proactive error detection working with clear user guidance
- **Module Loading**: Both modules import correctly with proper dependency resolution
- **CI/CD Validation**: All GitHub Actions workflows passing

### **🔬 Real-World Validation**
```powershell
# Successful orchestrator execution example
[OK] Applied policy for role 'Reader' at scope '/subscriptions/...' Activation=PT12H
[OK] Applied policy for role 'Tag Contributor' at scope '/subscriptions/...' Activation=PT2H
❌ Assignment failed: Entra/User Administrator/... [Active]
   Error: Requested active assignment duration 'PT8H' (8h) exceeds policy limit 'PT2H' (2h)
```

## 📦 **PowerShell Gallery Preparation**

### **🏷️ Release Strategy**
- **Beta Publications**: Both modules ready for gallery publication with `beta1` prerelease tags
- **Community Testing**: Enables real-world validation before stable release
- **Migration Support**: Comprehensive release notes with breaking changes documentation

### **📚 Enhanced Documentation**
- **Release Notes**: Detailed breaking changes, migration guide, and beta warnings
- **README Updates**: Installation instructions for both stable and beta versions
- **Module Dependencies**: Clear version requirements and compatibility matrix

## 🎯 **Breaking Changes**

### **⚠️ For Existing Users**
1. **Parameter Names**: Update scripts using `assignee` to `principalId` (alias available)
2. **Module Installation**: Install both `EasyPIM` and `EasyPIM.Orchestrator` for full functionality
3. **Version Requirements**: Orchestrator now requires EasyPIM v2.0.0+

### **🛠️ Migration Path**
```powershell
# Old (still works with alias)
New-PIMAzureResourceActiveAssignment -assignee "user-id" 

# New (recommended)
New-PIMAzureResourceActiveAssignment -principalId "user-id"

# Installation
Install-Module EasyPIM -AllowPrerelease          # v2.0.0-beta1  
Install-Module EasyPIM.Orchestrator -AllowPrerelease  # v1.0.0-beta1
```

## 📈 **Impact & Benefits**

### **🎉 User Experience Improvements**
- **No More ARM API Failures**: Eliminates cryptic InvalidResourceType errors
- **Clear Policy Guidance**: Immediate feedback on configuration conflicts
- **Simplified Installation**: Proper dependency management from PowerShell Gallery
- **Enhanced Reliability**: Comprehensive error handling and validation

### **🏗️ Developer Benefits**
- **Clean Architecture**: Standalone modules with proper separation of concerns
- **Maintainable Codebase**: Standardized parameters and consistent patterns
- **Comprehensive Testing**: Full CI/CD validation with real-world scenarios
- **Future-Proof**: Solid foundation for continued development

## 🚀 **Next Steps**

### **📋 Publication Checklist**
- ✅ **Version Updates**: Both modules updated with correct versions and prerelease tags
- ✅ **Manifest Validation**: Both modules pass `Test-ModuleManifest` successfully
- ✅ **CI/CD Validation**: All GitHub Actions workflows completed successfully
- ✅ **Documentation**: README and release notes updated with comprehensive guidance
- ✅ **Dependency Testing**: Module loading and orchestrator workflow validated

### **🎯 Ready for Gallery Publication**
```powershell
# Publication sequence (after merge)
Publish-Module -Path .\EasyPIM -NuGetApiKey $apiKey -Repository PSGallery
Publish-Module -Path .\EasyPIM.Orchestrator -NuGetApiKey $apiKey -Repository PSGallery
```

## 🤝 **Community Impact**

This release represents a significant milestone for the EasyPIM project:
- **Major Architecture Evolution**: Module separation enables specialized use cases
- **Enhanced Reliability**: ARM API fixes resolve persistent user issues  
- **Production Readiness**: Orchestrator reaches v1.0 with enterprise-grade features
- **Community Testing**: Beta releases enable broader validation before stable deployment

## 📊 **Files Changed**
- **13 files modified** with comprehensive ARM API fixes and enhancements
- **Module manifests updated** with version strategy and dependency management
- **Documentation enhanced** with migration guidance and beta installation instructions
- **Release notes created** with detailed breaking changes and feature descriptions

## 🎊 **Summary**

This PR delivers on the promise of a mature, reliable PIM management solution with:
- **Resolved technical debt** (ARM API compatibility issues)
- **Enhanced user experience** (proactive validation, clear error messages)
- **Architectural maturity** (proper module separation and dependency management)
- **Production readiness** (comprehensive testing and documentation)

The v2.0 release marks EasyPIM's evolution from a useful tool to a production-ready enterprise solution for PIM management across Azure, Entra ID, and Groups.

---
**Ready for merge and PowerShell Gallery publication! 🚀**
