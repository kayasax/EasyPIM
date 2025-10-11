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
            InvalidActivationRequirements = 0
            AutoCorrections = 0
        }
    }

    $getTemplateName = {
        param([psobject]$Policy)
        if (-not $Policy) { return $null }
        if ($Policy.PSObject.Properties['Template'] -and $Policy.Template) { return $Policy.Template }
        if ($Policy.PSObject.Properties['PolicyTemplate'] -and $Policy.PolicyTemplate) { return $Policy.PolicyTemplate }
        return $null
    }

    $processActivationRequirement = {
        param(
            [psobject]$Policy,
            [string]$Context,
            [psobject]$CorrectionTarget
        )

        if (-not $Policy) { return }

        foreach ($propertyName in @('ActivationRequirement', 'ActiveAssignmentRequirement')) {
            if (-not ($Policy.PSObject.Properties[$propertyName])) { continue }
            $value = $Policy.$propertyName
            if ($null -eq $value) { continue }

            $normalized = @()

            if ($value -is [string]) {
                if ($value -match ',') {
                    $normalized = ($value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                } else {
                    $trimmed = $value.Trim()
                    if ($trimmed) { $normalized = @($trimmed) }
                }
            } elseif ($value -is [System.Collections.IEnumerable]) {
                foreach ($item in $value) {
                    if ($null -eq $item) { continue }
                    $normalized += $item.ToString().Trim()
                }
                $normalized = @($normalized | Where-Object { $_ })
            } else {
                $normalized = @($value.ToString().Trim())
            }

            if ($normalized -contains 'AuthenticationContext') {
                $filtered = @($normalized | Where-Object { $_ -ne 'AuthenticationContext' -and $_ })
                $issue = [PSCustomObject]@{
                    Severity = 'Error'
                    Category = 'InvalidActivationRequirement'
                    Context = "$Context.$propertyName"
                    Message = "Invalid value 'AuthenticationContext' detected in $propertyName. This requirement is controlled by AuthenticationContext_Enabled and AuthenticationContext_Value."
                    Suggestion = "Remove 'AuthenticationContext' from $propertyName and rely on AuthenticationContext_Enabled plus AuthenticationContext_Value to enforce authentication context."
                }
                $validationResult.HasIssues = $true
                $validationResult.Issues += $issue
                $validationResult.ValidationSummary.InvalidActivationRequirements++

                if ($AutoCorrect -and $CorrectionTarget) {
                    $replacement = $filtered
                    if ($value -is [string]) {
                        $replacement = ($filtered -join ',')
                        if (-not $replacement) { $replacement = '' }
                    } elseif ($filtered.Count -eq 0) {
                        $replacement = @()
                    }

                    try {
                        $CorrectionTarget.PSObject.Properties[$propertyName] | Out-Null
                        $CorrectionTarget.$propertyName = $replacement
                    } catch {
                        try {
                            $CorrectionTarget | Add-Member -NotePropertyName $propertyName -NotePropertyValue $replacement -Force
                        } catch {
                            $CorrectionTarget.$propertyName = $replacement
                        }
                    }

                    try {
                        $Policy.$propertyName = $replacement
                    } catch {
                        # ignore if policy is immutable
                    }

                    $validationResult.Corrections += "Auto-removed 'AuthenticationContext' from $Context.$propertyName"
                    $validationResult.ValidationSummary.AutoCorrections++
                }
            }
        }
    }

    Write-Verbose "Starting EasyPIM configuration validation..."

    # Deep clone the config for corrections
    if ($AutoCorrect) {
        $validationResult.CorrectedConfig = $Config | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 100
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

        $templateCorrectionTarget = $null
        if ($AutoCorrect) {
            $templateCorrectionTarget = $validationResult.CorrectedConfig.PolicyTemplates.$templateName
        }
        & $processActivationRequirement -Policy $template -Context "PolicyTemplates.$templateName" -CorrectionTarget $templateCorrectionTarget
    }

    # Validation Rule 2a: Check EntraRolePolicies (top-level array) for Approvers mismatches
    if ($Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies) {
        Write-Verbose "Validating EntraRolePolicies (array format)..."

        if ($Config.EntraRolePolicies -is [System.Collections.IEnumerable] -and $Config.EntraRolePolicies -isnot [string]) {
            $index = 0
            foreach ($rolePolicy in $Config.EntraRolePolicies) {
                if (-not $rolePolicy) { $index++; continue }
                $roleName = if ($rolePolicy.PSObject.Properties['RoleName']) { $rolePolicy.RoleName } else { "Unknown" }
                $context = "EntraRolePolicies[$index] (RoleName: $roleName)"
                $templateName = & $getTemplateName $rolePolicy

                if ($rolePolicy.PSObject.Properties['Approvers'] -and $rolePolicy.Approvers) {
                    $approverIssues = Test-ApproversFormat -Approvers $rolePolicy.Approvers -Context $context

                    if ($approverIssues.HasIssues) {
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $approverIssues.Issues
                        $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                        if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                            $Config.EntraRolePolicies[$index].Approvers = $approverIssues.CorrectedApprovers
                            $validationResult.Corrections += "Auto-corrected Approvers format in $context"
                            $validationResult.ValidationSummary.AutoCorrections++
                        }
                    }
                }

                if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                    if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                        if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
                            $issue = [PSCustomObject]@{
                                Severity = "Error"
                                Category = "MissingApprovers"
                                Context = $context
                                Message = "ApprovalRequired is true but no Approvers defined and no Template specified"
                                Suggestion = "Add Approvers array or use a Template with Approvers defined"
                            }
                            $validationResult.HasIssues = $true
                            $validationResult.Issues += $issue
                            $validationResult.ValidationSummary.MissingRequiredFields++
                        }
                    }
                }

                $index++

                $policyCorrectionTarget = $null
                if ($AutoCorrect -and $validationResult.CorrectedConfig.PSObject.Properties['EntraRolePolicies']) {
                    $policyCorrectionTarget = $validationResult.CorrectedConfig.EntraRolePolicies[$index - 1]
                }
                & $processActivationRequirement -Policy $rolePolicy -Context $context -CorrectionTarget $policyCorrectionTarget
            }
        }
    }

    # Validation Rule 2b: Check EntraRoles.Policies for Approvers mismatches (both object and array formats)
    if ($Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies']) {
        Write-Verbose "Validating EntraRoles.Policies..."

        $entraPolicies = $Config.EntraRoles.Policies
        if ($entraPolicies -is [System.Collections.IEnumerable] -and $entraPolicies -isnot [string]) {
            $index = 0
            foreach ($rolePolicy in $entraPolicies) {
                if (-not $rolePolicy) { $index++; continue }
                $roleName = if ($rolePolicy.PSObject.Properties['RoleName']) { $rolePolicy.RoleName } else { "Unknown" }
                $context = "EntraRoles.Policies[$index] (RoleName: $roleName)"
                $templateName = & $getTemplateName $rolePolicy

                if ($rolePolicy.PSObject.Properties['Approvers'] -and $rolePolicy.Approvers) {
                    $approverIssues = Test-ApproversFormat -Approvers $rolePolicy.Approvers -Context $context

                    if ($approverIssues.HasIssues) {
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $approverIssues.Issues
                        $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                        if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                            $Config.EntraRoles.Policies[$index].Approvers = $approverIssues.CorrectedApprovers
                            $validationResult.Corrections += "Auto-corrected Approvers format in $context"
                            $validationResult.ValidationSummary.AutoCorrections++
                        }
                    }
                }

                if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                    if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                        if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
                            $issue = [PSCustomObject]@{
                                Severity = "Error"
                                Category = "MissingApprovers"
                                Context = $context
                                Message = "ApprovalRequired is true but no Approvers defined and no Template specified"
                                Suggestion = "Add Approvers array or use a Template with Approvers defined"
                            }
                            $validationResult.HasIssues = $true
                            $validationResult.Issues += $issue
                            $validationResult.ValidationSummary.MissingRequiredFields++
                        }
                    }
                }

                $index++

                $policyCorrectionTarget = $null
                if ($AutoCorrect -and $validationResult.CorrectedConfig.EntraRoles.PSObject.Properties['Policies']) {
                    $policyCorrectionTarget = $validationResult.CorrectedConfig.EntraRoles.Policies[$index - 1]
                }
                & $processActivationRequirement -Policy $rolePolicy -Context $context -CorrectionTarget $policyCorrectionTarget
            }
        } else {
            foreach ($roleName in $entraPolicies.PSObject.Properties.Name) {
                $rolePolicy = $entraPolicies.$roleName
                $templateName = & $getTemplateName $rolePolicy

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

                $policyCorrectionTarget = $null
                if ($AutoCorrect -and $validationResult.CorrectedConfig.EntraRoles.PSObject.Properties['Policies']) {
                    $policyCorrectionTarget = $validationResult.CorrectedConfig.EntraRoles.Policies.$roleName
                }
                & $processActivationRequirement -Policy $rolePolicy -Context "EntraRoles.Policies.$roleName" -CorrectionTarget $policyCorrectionTarget

                if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                    if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                        if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
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
    }

    # Validation Rule 3: Check AzureRoles policies for Approvers mismatches
    if ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies']) {
        Write-Verbose "Validating AzureRoles policies..."

        foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
            $rolePolicy = $Config.AzureRoles.Policies.$roleName
            $templateName = & $getTemplateName $rolePolicy

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

            $policyCorrectionTarget = $null
            if ($AutoCorrect -and $validationResult.CorrectedConfig.AzureRoles.PSObject.Properties['Policies']) {
                $policyCorrectionTarget = $validationResult.CorrectedConfig.AzureRoles.Policies.$roleName
            }
            & $processActivationRequirement -Policy $rolePolicy -Context "AzureRoles.Policies.$roleName" -CorrectionTarget $policyCorrectionTarget

            # Check for ApprovalRequired=true but missing Approvers
            if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                    if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
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

    # Validation Rule 3a: Check GroupPolicies (top-level array) for Approvers mismatches
    if ($Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies) {
        Write-Verbose "Validating GroupPolicies (array format)..."

        if ($Config.GroupPolicies -is [System.Collections.IEnumerable] -and $Config.GroupPolicies -isnot [string]) {
            $index = 0
            foreach ($groupPolicy in $Config.GroupPolicies) {
                if (-not $groupPolicy) { $index++; continue }
                $groupId = if ($groupPolicy.PSObject.Properties['GroupId']) { $groupPolicy.GroupId } else { "Unknown" }
                $groupName = if ($groupPolicy.PSObject.Properties['GroupName']) { $groupPolicy.GroupName } else { $groupId }
                $roleName = if ($groupPolicy.PSObject.Properties['RoleName']) { $groupPolicy.RoleName } else { "Unknown" }
                $context = "GroupPolicies[$index] (Group: $groupName, Role: $roleName)"
                $templateName = & $getTemplateName $groupPolicy

                if ($groupPolicy.PSObject.Properties['Approvers'] -and $groupPolicy.Approvers) {
                    $approverIssues = Test-ApproversFormat -Approvers $groupPolicy.Approvers -Context $context

                    if ($approverIssues.HasIssues) {
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $approverIssues.Issues
                        $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                        if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                            $Config.GroupPolicies[$index].Approvers = $approverIssues.CorrectedApprovers
                            $validationResult.Corrections += "Auto-corrected Approvers format in $context"
                            $validationResult.ValidationSummary.AutoCorrections++
                        }
                    }
                }

                if ($groupPolicy.PSObject.Properties['ApprovalRequired'] -and $groupPolicy.ApprovalRequired -eq $true) {
                    if (-not $groupPolicy.PSObject.Properties['Approvers'] -or -not $groupPolicy.Approvers -or $groupPolicy.Approvers.Count -eq 0) {
                        if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
                            $issue = [PSCustomObject]@{
                                Severity = "Error"
                                Category = "MissingApprovers"
                                Context = $context
                                Message = "ApprovalRequired is true but no Approvers defined and no Template specified"
                                Suggestion = "Add Approvers array or use a Template with Approvers defined"
                            }
                            $validationResult.HasIssues = $true
                            $validationResult.Issues += $issue
                            $validationResult.ValidationSummary.MissingRequiredFields++
                        }
                    }
                }

                $index++

                $groupPolicyCorrectionTarget = $null
                if ($AutoCorrect -and $validationResult.CorrectedConfig.PSObject.Properties['GroupPolicies']) {
                    $groupPolicyCorrectionTarget = $validationResult.CorrectedConfig.GroupPolicies[$index - 1]
                }
                & $processActivationRequirement -Policy $groupPolicy -Context $context -CorrectionTarget $groupPolicyCorrectionTarget
            }
        }
    }

    # Validation Rule 3b: Check Groups.Policies for Approvers mismatches (both object and array formats)
    if ($Config.PSObject.Properties['Groups'] -and $Config.Groups.PSObject.Properties['Policies']) {
        Write-Verbose "Validating Groups.Policies..."

        $groupPolicies = $Config.Groups.Policies
        if ($groupPolicies -is [System.Collections.IEnumerable] -and $groupPolicies -isnot [string]) {
            $index = 0
            foreach ($groupPolicy in $groupPolicies) {
                if (-not $groupPolicy) { $index++; continue }
                $groupId = if ($groupPolicy.PSObject.Properties['GroupId']) { $groupPolicy.GroupId } else { "Unknown" }
                $groupName = if ($groupPolicy.PSObject.Properties['GroupName']) { $groupPolicy.GroupName } else { $groupId }
                $roleName = if ($groupPolicy.PSObject.Properties['RoleName']) { $groupPolicy.RoleName } else { "Unknown" }
                $context = "Groups.Policies[$index] (Group: $groupName, Role: $roleName)"
                $templateName = & $getTemplateName $groupPolicy

                if ($groupPolicy.PSObject.Properties['Approvers'] -and $groupPolicy.Approvers) {
                    $approverIssues = Test-ApproversFormat -Approvers $groupPolicy.Approvers -Context $context

                    if ($approverIssues.HasIssues) {
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $approverIssues.Issues
                        $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                        if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                            $Config.Groups.Policies[$index].Approvers = $approverIssues.CorrectedApprovers
                            $validationResult.Corrections += "Auto-corrected Approvers format in $context"
                            $validationResult.ValidationSummary.AutoCorrections++
                        }
                    }
                }

                if ($groupPolicy.PSObject.Properties['ApprovalRequired'] -and $groupPolicy.ApprovalRequired -eq $true) {
                    if (-not $groupPolicy.PSObject.Properties['Approvers'] -or -not $groupPolicy.Approvers -or $groupPolicy.Approvers.Count -eq 0) {
                        if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
                            $issue = [PSCustomObject]@{
                                Severity = "Error"
                                Category = "MissingApprovers"
                                Context = $context
                                Message = "ApprovalRequired is true but no Approvers defined and no Template specified"
                                Suggestion = "Add Approvers array or use a Template with Approvers defined"
                            }
                            $validationResult.HasIssues = $true
                            $validationResult.Issues += $issue
                            $validationResult.ValidationSummary.MissingRequiredFields++
                        }
                    }
                }

                $index++

                $groupPolicyCorrectionTarget = $null
                if ($AutoCorrect -and $validationResult.CorrectedConfig.Groups.PSObject.Properties['Policies']) {
                    $groupPolicyCorrectionTarget = $validationResult.CorrectedConfig.Groups.Policies[$index - 1]
                }
                & $processActivationRequirement -Policy $groupPolicy -Context $context -CorrectionTarget $groupPolicyCorrectionTarget
            }
        } else {
            foreach ($groupKey in $groupPolicies.PSObject.Properties.Name) {
                $roleBlock = $groupPolicies.$groupKey
                if (-not $roleBlock) { continue }

                foreach ($roleProp in $roleBlock.PSObject.Properties) {
                    $roleName = $roleProp.Name
                    if ($roleName -notin @('Member', 'Owner')) { continue }
                    $rolePolicy = $roleProp.Value
                    $templateName = & $getTemplateName $rolePolicy

                    if ($rolePolicy.PSObject.Properties['Approvers'] -and $rolePolicy.Approvers) {
                        $approverIssues = Test-ApproversFormat -Approvers $rolePolicy.Approvers -Context "Groups.Policies.$groupKey.$roleName"

                        if ($approverIssues.HasIssues) {
                            $validationResult.HasIssues = $true
                            $validationResult.Issues += $approverIssues.Issues
                            $validationResult.ValidationSummary.ApproverFieldMismatches += $approverIssues.Issues.Count

                            if ($AutoCorrect -and $approverIssues.CorrectedApprovers) {
                                $validationResult.CorrectedConfig.Groups.Policies.$groupKey.$roleName.Approvers = $approverIssues.CorrectedApprovers
                                $validationResult.Corrections += "Auto-corrected Approvers format in Groups.Policies.$groupKey.$roleName"
                                $validationResult.ValidationSummary.AutoCorrections++
                            }
                        }
                    }

                    $groupPolicyCorrectionTarget = $null
                    if ($AutoCorrect -and $validationResult.CorrectedConfig.Groups.PSObject.Properties['Policies']) {
                        $groupPolicyCorrectionTarget = $validationResult.CorrectedConfig.Groups.Policies.$groupKey.$roleName
                    }
                    & $processActivationRequirement -Policy $rolePolicy -Context "Groups.Policies.$groupKey.$roleName" -CorrectionTarget $groupPolicyCorrectionTarget

                    if ($rolePolicy.PSObject.Properties['ApprovalRequired'] -and $rolePolicy.ApprovalRequired -eq $true) {
                        if (-not $rolePolicy.PSObject.Properties['Approvers'] -or -not $rolePolicy.Approvers -or $rolePolicy.Approvers.Count -eq 0) {
                            if ([string]::IsNullOrWhiteSpace([string]$templateName)) {
                                $issue = [PSCustomObject]@{
                                    Severity = "Error"
                                    Category = "MissingApprovers"
                                    Context = "Groups.Policies.$groupKey.$roleName"
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
        }
    }

    # Validation Rule 4: Check Template references exist
    $templateNames = if ($Config.PSObject.Properties['PolicyTemplates']) {
        $Config.PolicyTemplates.PSObject.Properties.Name
    } else {
        @()
    }

    # Check EntraRolePolicies (top-level array) template references
    if ($Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies) {
        if ($Config.EntraRolePolicies -is [System.Collections.IEnumerable] -and $Config.EntraRolePolicies -isnot [string]) {
            $index = 0
            foreach ($rolePolicy in $Config.EntraRolePolicies) {
                if (-not $rolePolicy) { $index++; continue }
                $roleName = if ($rolePolicy.PSObject.Properties['RoleName']) { $rolePolicy.RoleName } else { "Unknown" }
                $templateName = & $getTemplateName $rolePolicy
                
                if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                    if ($templateName -notin $templateNames) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "InvalidTemplateReference"
                            Context = "EntraRolePolicies[$index] (RoleName: $roleName)"
                            Message = "Template '$templateName' not found in PolicyTemplates"
                            Suggestion = "Check spelling or add the template to PolicyTemplates section"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.TemplateReferences++
                    }
                }
                $index++
            }
        }
    }

    # Check EntraRoles.Policies template references (both object and array formats)
    if ($Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies']) {
        $entraPolicies = $Config.EntraRoles.Policies
        if ($entraPolicies -is [System.Collections.IEnumerable] -and $entraPolicies -isnot [string]) {
            $index = 0
            foreach ($rolePolicy in $entraPolicies) {
                if (-not $rolePolicy) { $index++; continue }
                $roleName = if ($rolePolicy.PSObject.Properties['RoleName']) { $rolePolicy.RoleName } else { "Unknown" }
                $templateName = & $getTemplateName $rolePolicy

                if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                    if ($templateName -notin $templateNames) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "InvalidTemplateReference"
                            Context = "EntraRoles.Policies[$index] (RoleName: $roleName)"
                            Message = "Template '$templateName' not found in PolicyTemplates"
                            Suggestion = "Check spelling or add the template to PolicyTemplates section"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.TemplateReferences++
                    }
                }
                $index++
            }
        } else {
            foreach ($roleName in $entraPolicies.PSObject.Properties.Name) {
                $rolePolicy = $entraPolicies.$roleName
                $templateName = & $getTemplateName $rolePolicy
                if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                    if ($templateName -notin $templateNames) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "InvalidTemplateReference"
                            Context = "EntraRoles.Policies.$roleName"
                            Message = "Template '$templateName' not found in PolicyTemplates"
                            Suggestion = "Check spelling or add the template to PolicyTemplates section"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.TemplateReferences++
                    }
                }
            }
        }
    }

    # Check AzureRoles template references
    if ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies']) {
        foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
            $rolePolicy = $Config.AzureRoles.Policies.$roleName
            $templateName = & $getTemplateName $rolePolicy
            if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                if ($templateName -notin $templateNames) {
                    $issue = [PSCustomObject]@{
                        Severity = "Error"
                        Category = "InvalidTemplateReference"
                        Context = "AzureRoles.Policies.$roleName"
                        Message = "Template '$templateName' not found in PolicyTemplates"
                        Suggestion = "Check spelling or add the template to PolicyTemplates section"
                    }
                    $validationResult.HasIssues = $true
                    $validationResult.Issues += $issue
                    $validationResult.ValidationSummary.TemplateReferences++
                }
            }
        }
    }

    # Check GroupPolicies (top-level array) template references
    if ($Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies) {
        if ($Config.GroupPolicies -is [System.Collections.IEnumerable] -and $Config.GroupPolicies -isnot [string]) {
            $index = 0
            foreach ($groupPolicy in $Config.GroupPolicies) {
                if (-not $groupPolicy) { $index++; continue }
                $groupId = if ($groupPolicy.PSObject.Properties['GroupId']) { $groupPolicy.GroupId } else { "Unknown" }
                $groupName = if ($groupPolicy.PSObject.Properties['GroupName']) { $groupPolicy.GroupName } else { $groupId }
                $roleName = if ($groupPolicy.PSObject.Properties['RoleName']) { $groupPolicy.RoleName } else { "Unknown" }
                $templateName = & $getTemplateName $groupPolicy

                if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                    if ($templateName -notin $templateNames) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "InvalidTemplateReference"
                            Context = "GroupPolicies[$index] (Group: $groupName, Role: $roleName)"
                            Message = "Template '$templateName' not found in PolicyTemplates"
                            Suggestion = "Check spelling or add the template to PolicyTemplates section"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.TemplateReferences++
                    }
                }
                $index++
            }
        }
    }

    # Check Groups.Policies template references (both object and array formats)
    if ($Config.PSObject.Properties['Groups'] -and $Config.Groups.PSObject.Properties['Policies']) {
        $groupPolicies = $Config.Groups.Policies
        if ($groupPolicies -is [System.Collections.IEnumerable] -and $groupPolicies -isnot [string]) {
            $index = 0
            foreach ($groupPolicy in $groupPolicies) {
                if (-not $groupPolicy) { $index++; continue }
                $groupId = if ($groupPolicy.PSObject.Properties['GroupId']) { $groupPolicy.GroupId } else { "Unknown" }
                $groupName = if ($groupPolicy.PSObject.Properties['GroupName']) { $groupPolicy.GroupName } else { $groupId }
                $roleName = if ($groupPolicy.PSObject.Properties['RoleName']) { $groupPolicy.RoleName } else { "Unknown" }
                $templateName = & $getTemplateName $groupPolicy

                if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                    if ($templateName -notin $templateNames) {
                        $issue = [PSCustomObject]@{
                            Severity = "Error"
                            Category = "InvalidTemplateReference"
                            Context = "Groups.Policies[$index] (Group: $groupName, Role: $roleName)"
                            Message = "Template '$templateName' not found in PolicyTemplates"
                            Suggestion = "Check spelling or add the template to PolicyTemplates section"
                        }
                        $validationResult.HasIssues = $true
                        $validationResult.Issues += $issue
                        $validationResult.ValidationSummary.TemplateReferences++
                    }
                }
                $index++
            }
        } else {
            foreach ($groupKey in $groupPolicies.PSObject.Properties.Name) {
                $roleBlock = $groupPolicies.$groupKey
                if (-not $roleBlock) { continue }

                                $templateName = & $getTemplateName $rolePolicy
                                if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                                    if ($templateName -notin $templateNames) {
                    if ($roleName -notin @('Member', 'Owner')) { continue }
                    $rolePolicy = $roleProp.Value

                    if ($rolePolicy.PSObject.Properties['Template'] -and $rolePolicy.Template) {
                                            Message = "Template '$templateName' not found in PolicyTemplates"
                            $issue = [PSCustomObject]@{
                                Severity = "Error"
                                Category = "InvalidTemplateReference"
                                Context = "Groups.Policies.$groupKey.$roleName"
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
