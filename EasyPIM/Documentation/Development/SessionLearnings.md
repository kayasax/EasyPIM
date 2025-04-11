# EasyPIM Session Learnings

This document tracks key learnings, patterns, and notes from EasyPIM sessions for future reference.

## Session Notes - 2025-04-09

### Key Concepts

#### PIM Assignment Types
- **Eligible Assignments**: Require activation before permissions are granted
- **Active Assignments**: Immediate permissions without activation

#### Duration Formats
Durations in EasyPIM follow the ISO 8601 standard:
- \PT8H\: 8 hours
- \P1D\: 1 day
- \P2D\: 2 days
- \P1M\: 1 month
- \P90D\: 90 days

#### Assignment Properties
- **Permanent Assignment**: Set \\
Permanent\: true\ for assignments that don't expire
- **Time-bound Assignment**: Set \\Duration\: \P90D\\ for assignments with specific duration
- **Default Behavior**: If neither is specified, maximum allowed duration by policy will be used
- **Precedence**: If both \Permanent\ and \Duration\ are specified, \Permanent\ takes precedence

#### Multiple Principal Assignments
For assigning the same role to multiple principals with identical settings:
\\\json
\AzureRoles\: [
  {
    \PrincipalIds\: [
      \00000000-0000-0000-0000-000000000001\,
      \00000000-0000-0000-0000-000000000002\
    ],
    \Role\: \Reader\,
    \Scope\: \/subscriptions/12345678-1234-1234-1234-123456789012\,
    \Duration\: \P90D\
  }
]
\\\

### Azure Best Practices for PIM

1. **Least Privilege**: Assign the minimum necessary permissions
2. **Use Time-Bound Assignments**: Prefer time-bound over permanent assignments
3. **Protected Users**: Always maintain a list of protected users
4. **Regular Reviews**: Perform regular access reviews
5. **Activation Requirements**: Configure appropriate approval requirements for sensitive roles
6. **Monitoring**: Enable and review PIM audit logs regularly

### Common Usage Patterns

#### Pattern: Regular Access Review Automation
- Export current configuration
- Review and update as needed
- Apply updates using delta mode

#### Pattern: Environment Setup
- Prepare configuration JSON based on environment needs
- Store in KeyVault for secure access
- Apply using initial mode for first-time setup

### Notes for Future Sessions

- Add notes here as you learn new things in future sessions

## Session Notes - 2025-04-10

### API Access Patterns

#### Utility Functions for API Access

The EasyPIM module provides standardized utility functions for ARM and Graph API access:

1. **Invoke-ARM**: Used for Azure Resource Manager API calls
   - Located in `internal/functions/Invoke-ARM.ps1`
   - Parameters:
     - `restURI`: (Mandatory) The full URI to call
     - `method`: HTTP method to use (GET, POST, etc.)
     - `body`: Optional request body for POST/PUT/PATCH requests
   - Example:
     ```powershell
     $armUrl = "$scope/providers/Microsoft.Authorization/roleEligibilityScheduleRequests?api-version=2020-10-01"
     $response = Invoke-ARM -restURI $armUrl -method "GET"
     ```

2. **Invoke-Graph**: Used for Microsoft Graph API calls
   - Located in `internal/functions/Invoke-Graph.ps1`
   - Parameters:
     - `Endpoint`: The Graph API endpoint (without base URL)
     - `Method`: HTTP method (default: "GET")
     - `version`: API version (default: "v1.0", can use "beta")
     - `body`: Optional request body
   - Example:
     ```powershell
     $graphEndpoint = "roleManagement/directory/roleEligibilityScheduleRequests?`$filter=principalId eq '$principalId'"
     $response = Invoke-Graph -Endpoint $graphEndpoint -Method "GET" -version "beta"
     ```

#### Best Practices for API Access

When implementing new functions that require API calls to Azure or Microsoft Graph:

1. **Use Existing Helper Functions**: Always use `Invoke-ARM` and `Invoke-Graph` instead of direct `Invoke-RestMethod` calls
2. **Authentication Handling**: The helper functions handle authentication tokens automatically
3. **Error Handling**: The helper functions include consistent error handling
4. **Script Variables**: Remember that these functions use `$script:tenantID` and `$script:subscriptionID`

#### Common API Patterns

- **ARM Resource API**: `/subscriptions/{subId}/resourceGroups/{rgName}/providers/{providerName}/{resourceType}/{resourceName}/providers/Microsoft.Authorization/{resourceType}`
- **Graph API Directory**: `https://graph.microsoft.com/beta/roleManagement/directory/{endpointType}`
- **Graph API Groups**: `https://graph.microsoft.com/beta/roleManagement/directory/{endpointType}?$filter=resourceId eq '{groupId}'`

### Recent Function Updates

- **Test-AssignmentCreatedByOrchestrator**: Updated to use `Invoke-ARM` and `Invoke-Graph` instead of direct API calls
  - Uses `Invoke-ARM` for Azure role assignments
  - Uses `Invoke-Graph` for Entra ID and Group role assignments
  - This approach follows module standards and improves maintainability

## Session Notes - 2025-04-11

### Summary Display Issues

#### Property Naming Convention for Summary Counters
- **Issue**: The `Write-EasyPIMSummary` function was not displaying cleanup operation counters correctly because of property name mismatches.
- **Root Cause**: 
  - `Invoke-EasyPIMCleanup` returns an object with properties using "Count" suffix: `KeptCount`, `RemovedCount`, `SkippedCount`, `ProtectedCount`
  - `Write-EasyPIMSummary` was expecting properties without the suffix: `Kept`, `Removed`, `Skipped`, `Protected`
- **Solution**: Modified `Write-EasyPIMSummary` to check for both naming conventions with fallback logic:
  ```powershell
  $kept = if ($null -ne $CleanupResults.KeptCount) { $CleanupResults.KeptCount } 
          elseif ($null -ne $CleanupResults.Kept) { $CleanupResults.Kept }
          else { 0 }
  ```
- **Best Practice**: When updating or creating summary functions:
  - Use consistent property naming across the module
  - Handle multiple property name formats for backward compatibility
  - Document the expected property names in comments

### Code Quality Requirements

#### PSScriptAnalyzer Compliance
- **Trailing Spaces**: Avoid trailing spaces in code to pass PSScriptAnalyzer checks
  - Trailing spaces at the end of lines can trigger PSScriptAnalyzer warnings
  - These spaces are invisible and can cause inconsistent formatting
  - Most IDEs have settings to automatically trim trailing whitespace
  - Use VS Code's "Trim Trailing Whitespace" feature or configure auto-trimming on save
- **Best Practice**: 
  - Configure your editor to highlight or automatically remove trailing whitespace
  - Run PSScriptAnalyzer regularly during development to catch these issues early
  - Include PSScriptAnalyzer checks in your CI/CD pipeline

## Code Standards and Practices

### Naming Conventions
- **Use Singular Nouns**: Always use singular nouns for function names (e.g., `Get-PIMRole` not `Get-PIMRoles`)
- **Verb-Noun Format**: All functions follow PowerShell's standard Verb-Noun format
- **Approved Verbs**: Use only PowerShell approved verbs (Get, Set, New, Remove, etc.)

### Code Organization
- **Check Existing Helpers**: Before creating new helper functions, thoroughly check for existing helpers in the internal/functions directory
- **Avoid Duplication**: Reuse existing helper functions instead of creating duplicates
- **Function Documentation**: All functions should include comment-based help

### GitHub Copilot Session Continuity
- GitHub Copilot does not automatically remember previous conversations across different sessions
- This SessionLearnings.md file serves as a knowledge repository to maintain continuity
- When starting new sessions, reference this document for context about:
  - Coding standards and practices
  - Architectural decisions
  - Naming conventions
  - Commonly used patterns

### EasyPIM Module Structure
- **Public Functions**: Located in the functions/ directory with individual .ps1 files
- **Internal Functions**: Located in internal/functions/ directory
- **Configuration**: Stored in config/ directory
- **Documentation**: Maintained in Documentation/ directory

