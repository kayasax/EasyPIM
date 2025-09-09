function Test-EasyPIMConfigurationValidity {
    <#
    .SYNOPSIS
    Validates EasyPIM configuration and detects common mismatches.

    .DESCRIPTION
    Performs comprehensive validation of EasyPIM configuration objects to detect
    common field name mismatches, missing required properties, and other configuration
    issues that could cause runtime failures.

    .PARAMETER Config
    The configuration object to validate.

    .PARAMETER AutoCorrect
    If specified, attempts to automatically correct common issues.

    .OUTPUTS
    ValidationResult object containing any issues found and corrected configuration.

    .EXAMPLE
    $result = Test-EasyPIMConfigurationValidity -Config $config -AutoCorrect
    if ($result.HasIssues) {
        Write-Warning "Configuration issues found: $($result.Issues.Count)"
        $config = $result.CorrectedConfig
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [switch]$AutoCorrect
    )

    $validationResult = [PSCustomObject]@{
        HasIssues = $false
        Issues = @()
        Corrections = @()
        CorrectedConfig = $Config
        ValidationSummary = @{
            ApproverFieldMismatches = 0
            MissingRequiredFields = 0
            TemplateReferences = 0
            AutoCorrections = 0
        }
    }

    Write-Verbose "Starting EasyPIM configuration validation..."

    # Deep clone the config for corrections
    if ($AutoCorrect) {
        $validationResult.CorrectedConfig = $Config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    }

    # Validation Rule 1: Check PolicyTemplates for Approvers field mismatches
    if ($Config.PSObject.Properties['PolicyTemplates']) {
        Write-Verbose "Validating PolicyTemplates..."

        foreach ($templateName in $Config.PolicyTemplates.PSObject.Properties.Name) {
            $template = $Config.PolicyTemplates.$templateName

            if ($template.PSObject.Properties['Approvers'] -and $template.Approvers) {
                $approverIssues = Test-ApproversFormat -Approvers $template.Approvers -Context "PolicyTemplates.$templateName"

                if ($approverIssues.HasIssues) {
                    $validationResult.HasIssues = $true
                    $validationResult.Issues += $approverIssues.Issues
                    $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                    if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                        $validationResult.CorrectedConfig.PolicyTemplates.$templateName.Approvers = $approverIssues.CorrectedApprovers
                        $validationResult.Corrections += "Auto-corrected Approvers format in PolicyTemplates.$templateName"
                        $validationResult.ValidationSummary.AutoCorrections++
                    }
                }
            }
        }
    }

    # Validation Rule 2: Check EntraRoles policies for Approvers mismatches
    if ($Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies']) {
        Write-Verbose "Validating EntraRoles policies..."

        foreach ($roleName in $Config.EntraRoles.Policies.PSObject.Properties.Name) {
            $rolePolicy = $Config.EntraRoles.Policies.$roleName

            if ($rolePolicy.PSObject.Properties['Approvers'] -and $rolePolicy.Approvers) {
                $approverIssues = Test-ApproversFormat -Approvers $rolePolicy.Approvers -Context "EntraRoles.Policies.$roleName"

                if ($approverIssues.HasIssues) {
                    $validationResult.HasIssues = $true
                    $validationResult.Issues += $approverIssues.Issues
                    $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                    if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                        $validationResult.CorrectedConfig.EntraRoles.Policies.$roleName.Approvers = $approverIssues.CorrectedApprovers
                        $validationResult.Corrections += "Auto-corrected Approvers format in EntraRoles.Policies.$roleName"
                        $validationResult.ValidationSummary.AutoCorrections++
                    }
                }
            }

            # Check for ApprovalRequired=true but missing Approvers
            if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                    if (-not $rolePolicy.PSObject.Properties['Template'] -or -not $rolePolicy.Template) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "MissingApprovers"
                            Context = "EntraRoles.Policies.$roleName"
                            Message = "ApprovalRequired is true but no Approvers defined and no Template specified"
                            Suggestion = "Add Approvers array or use a Template with Approvers defined"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.MissingRequiredFields++
                    }
                }
            }
        }
    }

    # Validation Rule 3: Check AzureRoles policies for Approvers mismatches
    if ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies']) {
        Write-Verbose "Validating AzureRoles policies..."

        foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
            $rolePolicy = $Config.AzureRoles.Policies.$roleName

            if ($rolePolicy.PSObject.Properties['Approvers'] -and $rolePolicy.Approvers) {
                $approverIssues = Test-ApproversFormat -Approvers $rolePolicy.Approvers -Context "AzureRoles.Policies.$roleName"

                if ($approverIssues.HasIssues) {
                    $validationResult.HasIssues = $true
                    $validationResult.Issues += $approverIssues.Issues
                    $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                    if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                        $validationResult.CorrectedConfig.AzureRoles.Policies.$roleName.Approvers = $approverIssues.CorrectedApprovers
                        $validationResult.Corrections += "Auto-corrected Approvers format in AzureRoles.Policies.$roleName"
                        $validationResult.ValidationSummary.AutoCorrections++
                    }
                }
            }

            # Check for ApprovalRequired=true but missing Approvers
            if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                    if (-not $rolePolicy.PSObject.Properties['Template'] -or -not $rolePolicy.Template) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "MissingApprovers"
                            Context = "AzureRoles.Policies.$roleName"
                            Message = "ApprovalRequired is true but no Approvers defined and no Template specified"
                            Suggestion = "Add Approvers array or use a Template with Approvers defined"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.MissingRequiredFields++
                    }
                }
            }
        }
    }

    # Validation Rule 4: Check Template references exist
    $templateNames = if ($Config.PSObject.Properties['PolicyTemplates']) {
        $Config.PolicyTemplates.PSObject.Properties.Name
    } else {
        @()
    }

    # Check EntraRoles template references
    if ($Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies']) {
        foreach ($roleName in $Config.EntraRoles.Policies.PSObject.Properties.Name) {
            $rolePolicy = $Config.EntraRoles.Policies.$roleName
            if ($rolePolicy.PSObject.Properties['Template'] -and $rolePolicy.Template) {
                if ($rolePolicy.Template -notin $templateNames) {
                    $issue = [PSCustomObject]@{
                        Severity = "Error"
                        Category = "InvalidTemplateReference"
                        Context = "EntraRoles.Policies.$roleName"
                        Message = "Template '$($rolePolicy.Template)' not found in PolicyTemplates"
                        Suggestion = "Check spelling or add the template to PolicyTemplates section"
                    }
                    $validationResult.HasIssues = $true
                    $validationResult.Issues += $issue
                    $validationResult.ValidationSummary.TemplateReferences++
                }
            }
        }
    }

    # Check AzureRoles template references
    if ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies']) {
        foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
            $rolePolicy = $Config.AzureRoles.Policies.$roleName
            if ($rolePolicy.PSObject.Properties['Template'] -and $rolePolicy.Template) {
                if ($rolePolicy.Template -notin $templateNames) {
                    $issue = [PSCustomObject]@{
                        Severity = "Error"
                        Category = "InvalidTemplateReference"
                        Context = "AzureRoles.Policies.$roleName"
                        Message = "Template '$($rolePolicy.Template)' not found in PolicyTemplates"
                        Suggestion = "Check spelling or add the template to PolicyTemplates section"
                    }
                    $validationResult.HasIssues = $true
                    $validationResult.Issues += $issue
                    $validationResult.ValidationSummary.TemplateReferences++
                }
            }
        }
    }

    Write-Verbose "Configuration validation completed"
    Write-Verbose "   Issues found: $($validationResult.Issues.Count)"
    Write-Verbose "   Auto-corrections: $($validationResult.ValidationSummary.AutoCorrections)"

    return $validationResult
}

function Test-ApproversFormat {
    <#
    .SYNOPSIS
    Validates Approvers array format and detects common field name mismatches.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Approvers,

        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    $result = [PSCustomObject]@{
        HasIssues = $false
        Issues = @()
        CorrectedApprovers = $null
    }

    if (-not $Approvers -or $Approvers.Count -eq 0) {
        return $result
    }

    $correctedApprovers = @()
    $needsCorrection = $false

    for ($i = 0; $i -lt $Approvers.Count; $i++) {
        $approver = $Approvers[$i]
        $approverContext = "$Context.Approvers[$i]"
        $correctedApprover = @{}
        $approverNeedsCorrection = $false

        # Check for common field name mismatches (case-sensitive)
        $fieldMappings = @{
            'id' = 'Id'               # lowercase id -> Id
            'description' = 'Name'    # description -> Name
            'desc' = 'Name'           # desc -> Name
            'displayName' = 'Name'    # displayName -> Name
            'name' = 'Name'           # lowercase name -> Name (but not uppercase Name)
        }

        # Process each property in the approver
        $hasId = $false
        $hasName = $false

        foreach ($prop in $approver.PSObject.Properties) {
            $propName = $prop.Name
            $propValue = $prop.Value

            # Handle case-insensitive matching for ID -> Id (but keep exact matches)
            if ($propName -eq 'ID' -and $propName -ne 'Id') {
                $correctedApprover['Id'] = $propValue
                $approverNeedsCorrection = $true
                $hasId = $true

                $issue = [PSCustomObject]@{
                    Severity = "Warning"
                    Category = "FieldNameMismatch"
                    Context = $approverContext
                    Message = "Field '$propName' should be 'Id'"
                    Suggestion = "Change '$propName' to 'Id' in Approvers configuration"
                    OriginalField = $propName
                    CorrectedField = 'Id'
                }
                $result.HasIssues = $true
                $result.Issues += $issue
            } elseif ($propName -in @('id', 'description', 'desc', 'displayName', 'name') -and $propName -notin @('Id', 'Name')) {
                # Only correct if it's actually wrong (not already correct case)
                $correctName = switch ($propName) {
                    'id' { 'Id' }
                    'description' { 'Name' }
                    'desc' { 'Name' }
                    'displayName' { 'Name' }
                    'name' { 'Name' }
                }

                $correctedApprover[$correctName] = $propValue
                $approverNeedsCorrection = $true

                if ($correctName -eq 'Id') { $hasId = $true }
                if ($correctName -eq 'Name') { $hasName = $true }

                $issue = [PSCustomObject]@{
                    Severity = "Warning"
                    Category = "FieldNameMismatch"
                    Context = $approverContext
                    Message = "Field '$propName' should be '$correctName'"
                    Suggestion = "Change '$propName' to '$correctName' in Approvers configuration"
                    OriginalField = $propName
                    CorrectedField = $correctName
                }
                $result.HasIssues = $true
                $result.Issues += $issue
            } else {
                # Keep the property as-is (it's already correct or unknown)
                $correctedApprover[$propName] = $propValue

                if ($propName -eq 'Id') { $hasId = $true }
                if ($propName -eq 'Name') { $hasName = $true }
            }
        }

        # Check for missing required fields
        if (-not $hasId) {
            $issue = [PSCustomObject]@{
                Severity = "Error"
                Category = "MissingRequiredField"
                Context = $approverContext
                Message = "Missing required field 'Id'"
                Suggestion = "Add 'Id' field with the Object ID of the approver"
            }
            $result.HasIssues = $true
            $result.Issues += $issue
        }

        if (-not $hasName) {
            $issue = [PSCustomObject]@{
                Severity = "Warning"
                Category = "MissingRecommendedField"
                Context = $approverContext
                Message = "Missing recommended field 'Name'"
                Suggestion = "Add 'Name' field with a descriptive name for the approver"
            }
            $result.HasIssues = $true
            $result.Issues += $issue
        }

        if ($approverNeedsCorrection) {
            $needsCorrection = $true
        }

        $correctedApprovers += [PSCustomObject]$correctedApprover
    }

    if ($needsCorrection) {
        $result.CorrectedApprovers = $correctedApprovers
    }

    return $result
}
