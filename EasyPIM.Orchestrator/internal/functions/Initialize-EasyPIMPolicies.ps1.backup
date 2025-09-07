# Initialize-EasyPIMPolicies function for EasyPIM.Orchestrator
# Simplified version focused on the orchestrator's needs

function Initialize-EasyPIMPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [hashtable]$PolicyTemplates = @{},

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
        [string[]]$PolicyOperations = @("All"),

        [Parameter(Mandatory = $false)]
        [switch]$AllowProtectedRoles
    )

    Write-Verbose "Starting Initialize-EasyPIMPolicies (Orchestrator)"

    try {
        # Validate configuration before processing
        Write-Verbose "🔍 Validating configuration for common issues..."
        $validationResult = Test-EasyPIMConfigurationValidity -Config $Config -AutoCorrect

        if ($validationResult.HasIssues) {
            Write-Warning "⚠️ Configuration validation found $($validationResult.Issues.Count) issue(s):"

            foreach ($issue in $validationResult.Issues) {
                $severityColor = switch ($issue.Severity) {
                    'Error' { 'Red' }
                    'Warning' { 'Yellow' }
                    default { 'White' }
                }
                Write-Host "  [$($issue.Severity)] $($issue.Context): $($issue.Message)" -ForegroundColor $severityColor
                Write-Host "    💡 Suggestion: $($issue.Suggestion)" -ForegroundColor Cyan
            }

            if ($validationResult.Corrections.Count -gt 0) {
                Write-Host "✅ Auto-corrections applied:" -ForegroundColor Green
                foreach ($correction in $validationResult.Corrections) {
                    Write-Host "  + $correction" -ForegroundColor Green
                }
                # Use the corrected configuration
                $Config = $validationResult.CorrectedConfig
                Write-Host "📝 Using auto-corrected configuration for processing" -ForegroundColor Green
            }

            # Stop processing if there are errors that can't be auto-corrected
            $criticalErrors = $validationResult.Issues | Where-Object { $_.Severity -eq 'Error' }
            if ($criticalErrors.Count -gt 0) {
                $errorMessage = "Configuration validation failed with $($criticalErrors.Count) critical error(s). Please fix the configuration and try again."
                Write-Error $errorMessage
                throw $errorMessage
            }
        } else {
            Write-Verbose "✅ Configuration validation passed"
        }

        $processedConfig = @{}

        # Initialize policy templates - merge parameter and config templates
        $policyTemplates = $PolicyTemplates.Clone()
        if ($Config.PSObject.Properties['PolicyTemplates'] -and $Config.PolicyTemplates) {
            foreach ($templateName in $Config.PolicyTemplates.PSObject.Properties.Name) {
                $policyTemplates[$templateName] = $Config.PolicyTemplates.$templateName
            }
        }
        Write-Verbose "Found $($policyTemplates.Keys.Count) policy templates"

        $processAzure  = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'AzureRoles')
        $processEntra  = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'EntraRoles')
        $processGroups = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'GroupRoles')

        # New format sections - EntraRoles.Policies
        if ($processEntra -and $Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies'] -and $Config.EntraRoles.Policies) {
            Write-Verbose "Processing EntraRoles.Policies section"
            $processedConfig.EntraRolePolicies = @()
            foreach ($roleName in $Config.EntraRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.EntraRoles.Policies.$roleName
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; PolicySource = 'template'; Template = $policyContent.Template }

                    # 🆕 Copy any override properties from policyContent (excluding Template)
                    foreach ($prop in $policyContent.PSObject.Properties) {
                        if ($prop.Name -ne 'Template') {
                            $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                        }
                    }
                } else {
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; PolicySource = 'inline'; Policy = $policyContent }
                }
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'EntraRole'
                $processedConfig.EntraRolePolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies from EntraRoles.Policies"
        }

        # New format sections - AzureRoles.Policies
        if ($processAzure -and $Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies'] -and $Config.AzureRoles.Policies) {
            Write-Verbose "Processing AzureRoles.Policies section"
            $processedConfig.AzureRolePolicies = @()
            foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.AzureRoles.Policies.$roleName
                $scope = $null
                if ($policyContent.PSObject.Properties['Scope'] -and $policyContent.Scope) { $scope = $policyContent.Scope }
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'template'; Template = $policyContent.Template }

                    # 🆕 Copy any override properties from policyContent (excluding Template and Scope)
                    foreach ($prop in $policyContent.PSObject.Properties) {
                        if ($prop.Name -ne 'Template' -and $prop.Name -ne 'Scope') {
                            $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                        }
                    }
                } else {
                    $policyOnly = $policyContent | Select-Object -Property * -ExcludeProperty Scope
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'inline'; Policy = $policyOnly }
                }
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'AzureRole'
                $processedConfig.AzureRolePolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies from AzureRoles.Policies"
        }

        # New format sections - GroupRoles.Policies
        if ($processGroups -and $Config.PSObject.Properties['GroupRoles'] -and $Config.GroupRoles.PSObject.Properties['Policies'] -and $Config.GroupRoles.Policies) {
            Write-Verbose "Processing GroupRoles.Policies section"
            $processedConfig.GroupPolicies = @()
            foreach ($groupKey in $Config.GroupRoles.Policies.PSObject.Properties.Name) {
                $groupNode = $Config.GroupRoles.Policies.$groupKey
                $isGuid = $false
                if ($groupKey -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { $isGuid = $true }
                foreach ($roleProp in $groupNode.PSObject.Properties) {
                    $roleName = $roleProp.Name
                    if ($roleName -in @('Member','Owner')) {
                        $roleContent = $roleProp.Value
                        if ($roleContent.PSObject.Properties['Template'] -and $roleContent.Template) {
                            if ($isGuid) {
                                $policyDefinition = [PSCustomObject]@{ PolicySource = 'template'; Template = $roleContent.Template; RoleName = $roleName; GroupId = $groupKey }
                            } else {
                                $policyDefinition = [PSCustomObject]@{ PolicySource = 'template'; Template = $roleContent.Template; RoleName = $roleName; GroupName = $groupKey }
                            }

                            # 🆕 Copy any override properties from roleContent (excluding Template)
                            foreach ($prop in $roleContent.PSObject.Properties) {
                                if ($prop.Name -ne 'Template') {
                                    $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                                }
                            }
                        } else {
                            if ($isGuid) {
                                $policyDefinition = [PSCustomObject]@{ PolicySource = 'inline'; Policy = $roleContent; RoleName = $roleName; GroupId = $groupKey }
                            } else {
                                $policyDefinition = [PSCustomObject]@{ PolicySource = 'inline'; Policy = $roleContent; RoleName = $roleName; GroupName = $groupKey }
                            }
                        }
                        $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'Group'
                        $processedConfig.GroupPolicies += $processedPolicy
                    }
                }
            }
            Write-Verbose "Processed $($processedConfig.GroupPolicies.Count) Group policies from GroupRoles.Policies"
        }

        # Pass-through other sections
        $existingSections = @('AzureRoles', 'AzureRolesActive', 'EntraIDRoles', 'EntraIDRolesActive', 'GroupRoles', 'GroupRolesActive', 'ProtectedUsers', 'Assignments')
        foreach ($section in $existingSections) {
            if ($Config.PSObject.Properties[$section] -and $Config.$section) { $processedConfig[$section] = $Config.$section }
        }

        Write-Verbose "Initialize-EasyPIMPolicies completed successfully"
        return $processedConfig
    }
    catch {
        Write-Error "Failed to initialize PIM policies: $($_.Exception.Message)"
        throw
    }
}

function Resolve-PolicyConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [PSCustomObject]$PolicyDefinition,
        [Parameter(Mandatory = $true)] [hashtable]$Templates,
        [Parameter(Mandatory = $true)] [ValidateSet('AzureRole','EntraRole','Group')] [string]$PolicyType
    )

    # Helper function to auto-configure permanent assignment flags based on duration settings
    function Set-AutoPermanentFlags {
        param([PSCustomObject]$Policy, [string]$RoleName)

        if (-not $Policy) { return }

        $autoConfigured = @()

        # Auto-configure AllowPermanentEligibility based on MaximumEligibilityDuration
        if ($Policy.PSObject.Properties['MaximumEligibilityDuration'] -and
            $Policy.MaximumEligibilityDuration -and
            $Policy.MaximumEligibilityDuration -ne '') {

            if (-not $Policy.PSObject.Properties['AllowPermanentEligibility']) {
                $Policy | Add-Member -NotePropertyName 'AllowPermanentEligibility' -NotePropertyValue $false
                $autoConfigured += "AllowPermanentEligibility=false (MaximumEligibilityDuration specified)"
            }
        }

        # Auto-configure AllowPermanentActiveAssignment based on MaximumActiveAssignmentDuration
        if ($Policy.PSObject.Properties['MaximumActiveAssignmentDuration'] -and
            $Policy.MaximumActiveAssignmentDuration -and
            $Policy.MaximumActiveAssignmentDuration -ne '') {

            if (-not $Policy.PSObject.Properties['AllowPermanentActiveAssignment']) {
                $Policy | Add-Member -NotePropertyName 'AllowPermanentActiveAssignment' -NotePropertyValue $false
                $autoConfigured += "AllowPermanentActiveAssignment=false (MaximumActiveAssignmentDuration specified)"
            }
        }

        # Log auto-configuration for transparency
        if ($autoConfigured.Count -gt 0) {
            Write-Verbose "[Auto-Config] ${RoleName}: $($autoConfigured -join ', ')"
        }
    }

    Write-Verbose "Resolving policy configuration for $PolicyType"
    $resolvedPolicy = @{}

    # Copy non-empty properties from PolicyDefinition first
    foreach ($property in $PolicyDefinition.PSObject.Properties) {
        # Only copy non-empty values to allow template defaults to fill in blanks
        if ($null -ne $property.Value -and $property.Value -ne '') {
            $resolvedPolicy[$property.Name] = $property.Value
        }
    }

    switch ($PolicyType) {
        'AzureRole' { if (-not $PolicyDefinition.RoleName) { throw 'AzureRole policy missing required property: RoleName' }
                      if (-not $PolicyDefinition.Scope) { throw 'AzureRole policy missing required property: Scope' } }
        'EntraRole' { if (-not $PolicyDefinition.RoleName) { throw 'EntraRole policy missing required property: RoleName' } }
        'Group'     { if (-not $PolicyDefinition.GroupId -and -not $PolicyDefinition.GroupName) { throw 'Group policy missing required property: GroupId or GroupName' }
                      if (-not $PolicyDefinition.RoleName) { throw 'Group policy missing required property: RoleName' } }
    }

    $policySource = $PolicyDefinition.policySource
    if (-not $policySource) { if ($PolicyDefinition.template) { $policySource = 'template' } else { throw 'Policy definition missing policySource property' } }

    switch ($policySource.ToLower()) {
        'inline'   { if (-not $PolicyDefinition.policy) { throw 'Inline policy source specified but policy property is missing' }
                     $resolvedPolicy.ResolvedPolicy = $PolicyDefinition.policy
                     Set-AutoPermanentFlags -Policy $resolvedPolicy.ResolvedPolicy -RoleName $PolicyDefinition.RoleName }
        'template' { $templateName = $PolicyDefinition.template; if (-not $templateName) { $templateName = $PolicyDefinition.policyTemplate }
                     if (-not $templateName) { throw 'Template policy source specified but neither template nor policyTemplate property is provided' }
                     if (-not $Templates.ContainsKey($templateName)) { throw "Template '$templateName' not found in PolicyTemplates" }
                     $templatePolicy = $Templates[$templateName]

                     # Merge template policy with PolicyDefinition, allowing template to provide defaults
                     $mergedPolicy = @{}
                     # Start with template values as defaults
                     foreach ($templateProp in $templatePolicy.PSObject.Properties) {
                         $mergedPolicy[$templateProp.Name] = $templateProp.Value
                     }
                     # Override with ANY explicitly provided PolicyDefinition values (including false, empty string, etc.)
                     foreach ($property in $PolicyDefinition.PSObject.Properties) {
                         if ($property.Name -notin @('policySource', 'template', 'policyTemplate', 'policy')) {
                             $mergedPolicy[$property.Name] = $property.Value
                         }
                     }
                     $resolvedPolicy.ResolvedPolicy = [PSCustomObject]$mergedPolicy
                     Set-AutoPermanentFlags -Policy $resolvedPolicy.ResolvedPolicy -RoleName $PolicyDefinition.RoleName }
        default    { throw "Unknown policySource: $policySource" }
    }

    return [PSCustomObject]$resolvedPolicy
}
