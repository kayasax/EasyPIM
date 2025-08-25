# Requires -Version 5.1

# Shared version of policy initialization used by orchestrator and core.
# Sourced from EasyPIM/internal/functions/Initialize-EasyPIMPolicies.ps1 to avoid cross-module coupling.

function Initialize-EasyPIMPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "AzureRoles", "EntraRoles", "GroupRoles")]
        [string[]]$PolicyOperations = @("All")
    )

    Write-Verbose "Starting Initialize-EasyPIMPolicies"

    try {
        $processedConfig = @{}

        # Initialize policy templates if they exist
        $policyTemplates = @{}
        if ($Config.PSObject.Properties['PolicyTemplates'] -and $Config.PolicyTemplates) {
            foreach ($templateName in $Config.PolicyTemplates.PSObject.Properties.Name) {
                $policyTemplates[$templateName] = $Config.PolicyTemplates.$templateName
            }
            Write-Verbose "Found $($policyTemplates.Keys.Count) policy templates"
        }

        $processAzure  = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'AzureRoles')
        $processEntra  = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'EntraRoles')
        $processGroups = ($PolicyOperations -contains 'All' -or $PolicyOperations -contains 'GroupRoles')

        # Deprecated legacy sections support
        if ($processAzure -and $Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies) {
            Write-Warning "AzureRolePolicies format is deprecated. Please use AzureRoles.Policies.{RoleName} format instead."
            Write-Verbose "Processing deprecated AzureRolePolicies format"
            $processedConfig.AzureRolePolicies = @()
            foreach ($policy in $Config.AzureRolePolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "AzureRole"
                $processedConfig.AzureRolePolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies (deprecated format)"
        }

        if ($processEntra -and $Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies) {
            Write-Warning "EntraRolePolicies format is deprecated. Please use EntraRoles.Policies.{RoleName} format instead."
            Write-Verbose "Processing deprecated EntraRolePolicies format"
            $processedConfig.EntraRolePolicies = @()
            foreach ($policy in $Config.EntraRolePolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "EntraRole"
                $processedConfig.EntraRolePolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies (deprecated format)"
        }

        if ($processGroups -and $Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies) {
            Write-Warning "GroupPolicies format is deprecated. Please use GroupRoles.Policies.{GroupName} format instead."
            Write-Verbose "Processing deprecated GroupPolicies format"
            $processedConfig.GroupPolicies = @()
            foreach ($policy in $Config.GroupPolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "Group"
                $processedConfig.GroupPolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.GroupPolicies.Count) Group policies (deprecated format)"
        }

        if ($Config.PSObject.Properties['Policies'] -and $Config.Policies) {
            Write-Warning "Nested Policies.{Type} format is deprecated. Please use {Type}Roles.Policies.{RoleName} format instead."
            Write-Verbose "Processing deprecated consolidated Policies section"

            if ($processAzure -and $Config.Policies.PSObject.Properties['AzureRoles'] -and $Config.Policies.AzureRoles) {
                if (-not $processedConfig.ContainsKey('AzureRolePolicies')) { $processedConfig.AzureRolePolicies = @() }
                foreach ($policy in $Config.Policies.AzureRoles) {
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "AzureRole"
                    $processedConfig.AzureRolePolicies += $processedPolicy
                }
            }

            if ($processEntra -and $Config.Policies.PSObject.Properties['EntraRoles'] -and $Config.Policies.EntraRoles) {
                if (-not $processedConfig.ContainsKey('EntraRolePolicies')) { $processedConfig.EntraRolePolicies = @() }
                foreach ($policy in $Config.Policies.EntraRoles) {
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "EntraRole"
                    $processedConfig.EntraRolePolicies += $processedPolicy
                }
            }

            if ($processGroups -and $Config.Policies.PSObject.Properties['Groups'] -and $Config.Policies.Groups) {
                if (-not $processedConfig.ContainsKey('GroupPolicies')) { $processedConfig.GroupPolicies = @() }
                foreach ($policy in $Config.Policies.Groups) {
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "Group"
                    $processedConfig.GroupPolicies += $processedPolicy
                }
            }
        }

        # New format sections
        if ($processEntra -and $Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies'] -and $Config.EntraRoles.Policies) {
            Write-Verbose "Processing EntraRoles.Policies section"
            $processedConfig.EntraRolePolicies = @()
            foreach ($roleName in $Config.EntraRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.EntraRoles.Policies.$roleName
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; PolicySource = 'template'; Template = $policyContent.Template }
                } else {
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; PolicySource = 'inline'; Policy = $policyContent }
                }
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'EntraRole'
                $processedConfig.EntraRolePolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies from EntraRoles.Policies"
        }

        if ($processAzure -and $Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies'] -and $Config.AzureRoles.Policies) {
            Write-Verbose "Processing AzureRoles.Policies section"
            $processedConfig.AzureRolePolicies = @()
            foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.AzureRoles.Policies.$roleName
                $scope = $null
                if ($policyContent.PSObject.Properties['Scope'] -and $policyContent.Scope) { $scope = $policyContent.Scope }
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'template'; Template = $policyContent.Template }
                } else {
                    $policyOnly = $policyContent | Select-Object -Property * -ExcludeProperty Scope
                    $policyDefinition = [PSCustomObject]@{ RoleName = $roleName; Scope = $scope; PolicySource = 'inline'; Policy = $policyOnly }
                }
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType 'AzureRole'
                $processedConfig.AzureRolePolicies += $processedPolicy
            }
            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies from AzureRoles.Policies"
        }

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

    Write-Verbose "Resolving policy configuration for $PolicyType"
    $resolvedPolicy = @{}
    foreach ($property in $PolicyDefinition.PSObject.Properties) { $resolvedPolicy[$property.Name] = $property.Value }

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
                     $resolvedPolicy.ResolvedPolicy = $PolicyDefinition.policy }
        'file'     { if (-not $PolicyDefinition.policyFile) { throw 'File policy source specified but policyFile property is missing' }
                     if (-not (Test-Path $PolicyDefinition.policyFile)) { throw "Policy file not found: $($PolicyDefinition.policyFile)" }
                     $csvData = Import-Csv $PolicyDefinition.policyFile
                     $resolvedPolicy.ResolvedPolicy = ConvertFrom-PolicyCSV -CsvData $csvData -PolicyType $PolicyType }
        'template' { $templateName = $PolicyDefinition.template; if (-not $templateName) { $templateName = $PolicyDefinition.policyTemplate }
                     if (-not $templateName) { throw 'Template policy source specified but neither template nor policyTemplate property is provided' }
                     if (-not $Templates.ContainsKey($templateName)) { throw "Template '$templateName' not found in PolicyTemplates" }
                     $templatePolicy = $Templates[$templateName]
                     $resolvedPolicy.ResolvedPolicy = $templatePolicy }
        default    { throw "Unknown policySource: $policySource" }
    }

    return [PSCustomObject]$resolvedPolicy
}

function ConvertFrom-PolicyCSV {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [Object[]]$CsvData,
        [Parameter(Mandatory = $true)] [ValidateSet('AzureRole','EntraRole','Group')] [string]$PolicyType
    )

    # Placeholder: implement CSV-to-policy conversion as in core if needed later
    throw "CSV policy conversion is not implemented in the shared module. Use template or inline policies."
}
