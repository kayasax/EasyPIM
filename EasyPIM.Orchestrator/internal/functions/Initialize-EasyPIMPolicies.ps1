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
        # Simplified validation - skip complex validation for now
        Write-Verbose "� Processing configuration..."

        $processedConfig = @{}

        # Initialize policy templates - merge parameter and config templates
        $policyTemplates = $PolicyTemplates.Clone()
        if ($Config.PSObject.Properties['PolicyTemplates'] -and $Config.PolicyTemplates) {
            $cfgTemplates = $Config.PolicyTemplates
            if ($cfgTemplates -is [System.Collections.IDictionary]) {
                foreach ($templateName in $cfgTemplates.Keys) {
                    $policyTemplates[$templateName] = $cfgTemplates[$templateName]
                }
            } else {
                foreach ($templateName in $cfgTemplates.PSObject.Properties.Name) {
                    $policyTemplates[$templateName] = $cfgTemplates.$templateName
                }
            }
        }
        Write-Verbose "Found $($policyTemplates.Keys.Count) policy templates"

        $processAzure  = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'AzureRoles')
        $processEntra  = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'EntraRoles')
        $processGroups = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'GroupRoles')

        # Entra policy source detection and conflict check
        $entraArrayTopPresent = ($Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies)
        $entraNestedPresent   = ($Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies'] -and $Config.EntraRoles.Policies)

        if ($processEntra -and $entraArrayTopPresent -and $entraNestedPresent) {
            throw "Both EntraRolePolicies and EntraRoles.Policies are present. Only one format is allowed."
        }

        if ($processEntra -and ($entraArrayTopPresent -or $entraNestedPresent)) {
            Write-Verbose "Processing Entra Role policies"
            if (-not $processedConfig.PSObject.Properties['EntraRolePolicies']) {
                $processedConfig.EntraRolePolicies = @()
            }

            $polNode = if ($entraNestedPresent) { $Config.EntraRoles.Policies } else { $Config.EntraRolePolicies }
            $sourceLabel = if ($entraNestedPresent) { "EntraRoles.Policies" } else { "EntraRolePolicies" }

            if ($polNode -is [System.Collections.IDictionary] -or
                ($polNode -is [psobject] -and
                 $polNode.PSObject -and
                 $polNode.PSObject.Properties.Count -gt 0 -and
                 -not ($polNode -is [System.Collections.IEnumerable] -and $polNode -isnot [string]))) {

                Write-Verbose "Processing $sourceLabel as object/dictionary format"
                foreach ($roleName in $polNode.PSObject.Properties.Name) {
                    $policyContent = $polNode.$roleName
                    if (-not $policyContent) { continue }

                    if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                        $policyDefinition = [PSCustomObject]@{
                            RoleName = $roleName
                            PolicySource = 'template'
                            Template = $policyContent.Template
                        }
                        foreach ($prop in $policyContent.PSObject.Properties) {
                            if ($prop.Name -ne 'Template') {
                                $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                            }
                        }
                    } else {
                        $policyDefinition = [PSCustomObject]@{
                            RoleName = $roleName
                            PolicySource = 'inline'
                            Policy = $policyContent
                        }
                    }
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'EntraRole'
                    $processedConfig.EntraRolePolicies += $processedPolicy
                }
            }
            elseif ($polNode -is [System.Collections.IEnumerable] -and $polNode -isnot [string]) {
                Write-Verbose "Processing $sourceLabel as array format"
                foreach ($entry in $polNode) {
                    if (-not ($entry -is [psobject])) { continue }

                    $roleName = if ($entry.PSObject.Properties['RoleName']) { $entry.RoleName } else { $null }
                    if (-not $roleName) {
                        throw "EntraRole array policy entry missing required property: RoleName"
                    }

                    $hasTemplate = ($entry.PSObject.Properties['Template'] -and $entry.Template)
                    $hasInlinePolicy = ($entry.PSObject.Properties['Policy'] -and $entry.Policy)
                    $hasPolicySource = ($entry.PSObject.Properties['PolicySource'] -and $entry.PolicySource)

                    if ($hasTemplate) {
                        $policyDefinition = [PSCustomObject]@{
                            RoleName = $roleName
                            PolicySource = 'template'
                            Template = $entry.Template
                        }
                        foreach ($prop in $entry.PSObject.Properties) {
                            if ($prop.Name -notin @('Template', 'RoleName', 'Policy')) {
                                try {
                                    $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                                } catch {
                                }
                            }
                        }
                    }
                    elseif ($hasInlinePolicy -or ($hasPolicySource -and $entry.PolicySource -eq 'inline')) {
                        $inlinePolicy = if ($hasInlinePolicy) {
                            $entry.Policy
                        } else {
                            $props = @{}
                            foreach ($prop in $entry.PSObject.Properties) {
                                if ($prop.Name -notin @('RoleName', 'Template', 'PolicySource')) {
                                    $props[$prop.Name] = $prop.Value
                                }
                            }
                            [PSCustomObject]$props
                        }
                        $policyDefinition = [PSCustomObject]@{
                            RoleName = $roleName
                            PolicySource = 'inline'
                            Policy = $inlinePolicy
                        }
                    }
                    else {
                        throw "EntraRole array policy requires Template or inline Policy for role '$roleName'"
                    }

                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'EntraRole'
                    $processedConfig.EntraRolePolicies += $processedPolicy
                }
            }
            else {
                throw "Unsupported type for Entra policies: $($polNode.GetType().FullName)"
            }

            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies from $sourceLabel"
        }

        # Azure policy source detection and conflict check
        $azureArrayPresent = ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies'] -and $Config.AzureRoles.Policies)
        $azureObjectPresent = ($Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies)

        if ($processAzure -and $azureArrayPresent -and $azureObjectPresent) {
            throw "Both AzureRoles.Policies and AzureRolePolicies are present. Only one format is allowed."
        }
        # New format sections - AzureRoles.Policies
        if ($processAzure -and (($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies'] -and $Config.AzureRoles.Policies) -or ($Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies))) {
            $processedConfig.AzureRolePolicies = @()
            $polNode = $null
            if ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies'] -and $Config.AzureRoles.Policies) {
                Write-Verbose "Processing AzureRoles.Policies section"
                $polNode = $Config.AzureRoles.Policies
            } elseif ($Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies) {
                Write-Verbose "Processing legacy AzureRolePolicies section"
                $polNode = $Config.AzureRolePolicies
            }

            # Backward-compatible dictionary/object format: { "RoleName": { ... } }
            if ($polNode -is [System.Collections.IDictionary] -or ($polNode -is [psobject] -and $polNode.PSObject -and $polNode.PSObject.Properties.Count -gt 0)) {
                foreach ($roleName in $polNode.PSObject.Properties.Name) {
                    $policyContent = $polNode.$roleName
                    $scope = $null
                    if ($policyContent.PSObject.Properties['Scope'] -and $policyContent.Scope) { $scope = $policyContent.Scope }
                    $templateName = $null
                    if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                        $templateName = $policyContent.Template
                    } elseif ($policyContent.PSObject.Properties['PolicyTemplate'] -and $policyContent.PolicyTemplate) {
                        $templateName = $policyContent.PolicyTemplate
                    }

                    if ($templateName -is [string]) { $templateName = $templateName.Trim() }

                    if (-not [string]::IsNullOrWhiteSpace([string]$templateName)) {
                        $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'template'; Template = $templateName }
                        foreach ($prop in $policyContent.PSObject.Properties) {
                            if ($prop.Name -notin @('Template','PolicyTemplate','Scope')) {
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
            }
            # New array format: [ { RoleName, Scope, Template|Policy, PolicySource, ... }, ... ]
            elseif ($polNode -is [System.Collections.IEnumerable]) {
                foreach ($entry in $polNode) {
                    if (-not ($entry -is [psobject])) { continue }
                    $roleName = $null
                    if ($entry.PSObject.Properties['RoleName']) { $roleName = $entry.RoleName }
                    $scope = $null
                    if ($entry.PSObject.Properties['Scope']) { $scope = $entry.Scope }

                    if (-not $roleName) { throw "AzureRole array policy missing required property: RoleName" }
                    if (-not $scope) { throw "AzureRole array policy missing required property: Scope for role '$roleName'" }

                    $policyDefinition = $null
                    $templateName = $null
                    if ($entry.PSObject.Properties['Template'] -and $entry.Template) {
                        $templateName = $entry.Template
                    } elseif ($entry.PSObject.Properties['PolicyTemplate'] -and $entry.PolicyTemplate) {
                        $templateName = $entry.PolicyTemplate
                    }

                    if ($templateName -is [string]) { $templateName = $templateName.Trim() }

                    $hasTemplate = (-not [string]::IsNullOrWhiteSpace([string]$templateName))
                    $hasInline   = ($entry.PSObject.Properties['Policy'] -and $entry.Policy)

                    if ($hasTemplate) {
                        $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'template'; Template = $templateName }
                        foreach ($prop in $entry.PSObject.Properties) {
                            if ($prop.Name -notin @('Template','PolicyTemplate','Scope','RoleName','Policy')) {
                                try { $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force } catch { }
                            }
                        }
                    } elseif ($hasInline -or ($entry.PSObject.Properties['PolicySource'] -and ($entry.PolicySource -eq 'inline'))) {
                        $inlinePolicy = $null
                        if ($hasInline) { $inlinePolicy = $entry.Policy } else { $inlinePolicy = ($entry | Select-Object -Property * -ExcludeProperty RoleName,Scope,Template,PolicySource) }
                        $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'inline'; Policy = $inlinePolicy }
                    } else {
                        throw "AzureRole array policy requires Template or Inline Policy for role '$roleName' at scope '$scope'"
                    }

                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'AzureRole'
                    $processedConfig.AzureRolePolicies += $processedPolicy
                }
            }
            else {
                throw "Unsupported type for AzureRoles.Policies: $($polNode.GetType().FullName)"
            }

            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies from AzureRoles.Policies"
        }

        # Group policy source detection and conflict check
        $groupArrayTopPresent = ($Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies)
        $groupNestedPresent   = ($Config.PSObject.Properties['Groups'] -and $Config.Groups.PSObject.Properties['Policies'] -and $Config.Groups.Policies)
        $groupLegacyPresent   = ($Config.PSObject.Properties['GroupRoles'] -and $Config.GroupRoles.PSObject.Properties['Policies'] -and $Config.GroupRoles.Policies)

        if ($processGroups -and (($groupArrayTopPresent -and $groupNestedPresent) -or ($groupArrayTopPresent -and $groupLegacyPresent) -or ($groupNestedPresent -and $groupLegacyPresent))) {
            throw "Multiple Group policy formats are present (GroupPolicies, Groups.Policies, GroupRoles.Policies). Only one format is allowed."
        }

        if ($processGroups -and ($groupArrayTopPresent -or $groupNestedPresent -or $groupLegacyPresent)) {
            Write-Verbose "Processing Group policies"
            if (-not $processedConfig.PSObject.Properties['GroupPolicies']) {
                $processedConfig.GroupPolicies = @()
            }

            $polNode = $null
            $sourceLabel = ""
            if ($groupArrayTopPresent) {
                $polNode = $Config.GroupPolicies
                $sourceLabel = "GroupPolicies"
            } elseif ($groupNestedPresent) {
                $polNode = $Config.Groups.Policies
                $sourceLabel = "Groups.Policies"
            } else {
                $polNode = $Config.GroupRoles.Policies
                $sourceLabel = "GroupRoles.Policies"
            }

            # Check if polNode is an array or object format
            if ($polNode -is [System.Collections.IEnumerable] -and $polNode -isnot [string]) {
                Write-Verbose "Processing $sourceLabel as array format"
                foreach ($entry in $polNode) {
                    if (-not ($entry -is [psobject])) { continue }

                    $groupId = if ($entry.PSObject.Properties['GroupId']) { $entry.GroupId } else { $null }
                    $groupName = if ($entry.PSObject.Properties['GroupName']) { $entry.GroupName } else { $null }

                    if (-not $groupId -and -not $groupName) {
                        throw "Group array policy entry missing required property: GroupId or GroupName"
                    }

                    $roleName = if ($entry.PSObject.Properties['RoleName']) { $entry.RoleName } else { $null }
                    if (-not $roleName) {
                        throw "Group array policy entry missing required property: RoleName"
                    }

                    if ($roleName -notin @('Member', 'Owner')) {
                        throw "Group array policy RoleName must be 'Member' or 'Owner', got: $roleName"
                    }

                    $hasTemplate = ($entry.PSObject.Properties['Template'] -and $entry.Template)
                    $hasInlinePolicy = ($entry.PSObject.Properties['Policy'] -and $entry.Policy)
                    $hasPolicySource = ($entry.PSObject.Properties['PolicySource'] -and $entry.PolicySource)

                    if ($hasTemplate) {
                        $policyDefinition = [PSCustomObject]@{
                            PolicySource = 'template'
                            Template = $entry.Template
                            RoleName = $roleName
                        }
                        if ($groupId) {
                            $policyDefinition | Add-Member -NotePropertyName 'GroupId' -NotePropertyValue $groupId -Force
                        }
                        if ($groupName) {
                            $policyDefinition | Add-Member -NotePropertyName 'GroupName' -NotePropertyValue $groupName -Force
                        }
                        foreach ($prop in $entry.PSObject.Properties) {
                            if ($prop.Name -notin @('Template', 'RoleName', 'GroupId', 'GroupName', 'Policy')) {
                                try {
                                    $policyDefinition | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                                } catch {
                                }
                            }
                        }
                    }
                    elseif ($hasInlinePolicy -or ($hasPolicySource -and $entry.PolicySource -eq 'inline')) {
                        $inlinePolicy = if ($hasInlinePolicy) {
                            $entry.Policy
                        } else {
                            $props = @{}
                            foreach ($prop in $entry.PSObject.Properties) {
                                if ($prop.Name -notin @('RoleName', 'GroupId', 'GroupName', 'Template', 'PolicySource')) {
                                    $props[$prop.Name] = $prop.Value
                                }
                            }
                            [PSCustomObject]$props
                        }
                        $policyDefinition = [PSCustomObject]@{
                            PolicySource = 'inline'
                            Policy = $inlinePolicy
                            RoleName = $roleName
                        }
                        if ($groupId) {
                            $policyDefinition | Add-Member -NotePropertyName 'GroupId' -NotePropertyValue $groupId -Force
                        }
                        if ($groupName) {
                            $policyDefinition | Add-Member -NotePropertyName 'GroupName' -NotePropertyValue $groupName -Force
                        }
                    }
                    else {
                        throw "Group array policy requires Template or inline Policy for group $($groupId ?? $groupName) role $roleName"
                    }

                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'Group'
                    $processedConfig.GroupPolicies += $processedPolicy
                }
            }
            else {
                Write-Verbose "Processing $sourceLabel as object format"
                foreach ($groupKey in $polNode.PSObject.Properties.Name) {
                    $groupNode = $polNode.$groupKey
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
            }
            Write-Verbose "Processed $($processedConfig.GroupPolicies.Count) Group policies from $sourceLabel"
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
