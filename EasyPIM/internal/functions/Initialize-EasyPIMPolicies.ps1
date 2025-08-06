#Requires -Version 5.1

# PSScriptAnalyzer suppressions for this internal policy orchestration file
# The "Policies" plural naming is intentional as it initializes multiple policies collectively

function Initialize-EasyPIMPolicies {
    <#
    .SYNOPSIS
        Initializes and processes PIM policy configurations from the orchestrator config.

    .DESCRIPTION
        This function processes policy definitions from the configuration file, resolves policy templates,
        validates policy sources, and prepares the policy configuration for application.

    .PARAMETER Config
        The configuration object containing policy definitions

    .EXAMPLE
        $processedPolicies = Initialize-EasyPIMPolicies -Config $config

    .NOTES
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    Write-Verbose "Starting Initialize-EasyPIMPolicies"

    try {
        $processedConfig = @{}

        # Initialize policy templates if they exist
        $policyTemplates = @{}
        if ($Config.PSObject.Properties['PolicyTemplates'] -and $Config.PolicyTemplates) {
            # Convert PSCustomObject to hashtable for easier processing
            foreach ($templateName in $Config.PolicyTemplates.PSObject.Properties.Name) {
                $policyTemplates[$templateName] = $Config.PolicyTemplates.$templateName
            }
            Write-Verbose "Found $($policyTemplates.Keys.Count) policy templates"
        }

        # Process Azure Role Policies - DEPRECATED: Use AzureRoles.Policies format instead
        # Keeping minimal support for backward compatibility but recommend migration
        if ($Config.PSObject.Properties['AzureRolePolicies'] -and $Config.AzureRolePolicies) {
            Write-Warning "AzureRolePolicies format is deprecated. Please use AzureRoles.Policies.{RoleName} format instead."
            Write-Verbose "Processing deprecated AzureRolePolicies format"
            $processedConfig.AzureRolePolicies = @()

            foreach ($policy in $Config.AzureRolePolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "AzureRole"
                $processedConfig.AzureRolePolicies += $processedPolicy
            }

            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies (deprecated format)"
        }

        # Process Entra Role Policies - DEPRECATED: Use EntraRoles.Policies format instead
        # Keeping minimal support for backward compatibility but recommend migration
        if ($Config.PSObject.Properties['EntraRolePolicies'] -and $Config.EntraRolePolicies) {
            Write-Warning "EntraRolePolicies format is deprecated. Please use EntraRoles.Policies.{RoleName} format instead."
            Write-Verbose "Processing deprecated EntraRolePolicies format"
            $processedConfig.EntraRolePolicies = @()

            foreach ($policy in $Config.EntraRolePolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "EntraRole"
                $processedConfig.EntraRolePolicies += $processedPolicy
            }

            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies (deprecated format)"
        }

        # Process Group Policies - DEPRECATED: Use GroupRoles.Policies format instead
        # Keeping minimal support for backward compatibility but recommend migration
        if ($Config.PSObject.Properties['GroupPolicies'] -and $Config.GroupPolicies) {
            Write-Warning "GroupPolicies format is deprecated. Please use GroupRoles.Policies.{GroupName} format instead."
            Write-Verbose "Processing deprecated GroupPolicies format"
            $processedConfig.GroupPolicies = @()

            foreach ($policy in $Config.GroupPolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "Group"
                $processedConfig.GroupPolicies += $processedPolicy
            }

            Write-Verbose "Processed $($processedConfig.GroupPolicies.Count) Group policies (deprecated format)"
        }

        # Process the "Policies" section - DEPRECATED: Use {Type}Roles.Policies format instead
        # Keeping minimal support for backward compatibility but recommend migration
        if ($Config.PSObject.Properties['Policies'] -and $Config.Policies) {
            Write-Warning "Nested Policies.{Type} format is deprecated. Please use {Type}Roles.Policies.{RoleName} format instead."
            Write-Verbose "Processing deprecated consolidated Policies section"

            # Process Azure Role Policies from Policies section
            if ($Config.Policies.PSObject.Properties['AzureRoles'] -and $Config.Policies.AzureRoles) {
                if (-not $processedConfig.ContainsKey('AzureRolePolicies')) {
                    $processedConfig.AzureRolePolicies = @()
                }
                foreach ($policy in $Config.Policies.AzureRoles) {
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "AzureRole"
                    $processedConfig.AzureRolePolicies += $processedPolicy
                }
            }

            # Process Entra Role Policies from Policies section
            if ($Config.Policies.PSObject.Properties['EntraRoles'] -and $Config.Policies.EntraRoles) {
                if (-not $processedConfig.ContainsKey('EntraRolePolicies')) {
                    $processedConfig.EntraRolePolicies = @()
                }
                foreach ($policy in $Config.Policies.EntraRoles) {
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "EntraRole"
                    $processedConfig.EntraRolePolicies += $processedPolicy
                }
            }

            # Process Group Policies from Policies section
            if ($Config.Policies.PSObject.Properties['Groups'] -and $Config.Policies.Groups) {
                if (-not $processedConfig.ContainsKey('GroupPolicies')) {
                    $processedConfig.GroupPolicies = @()
                }
                foreach ($policy in $Config.Policies.Groups) {
                    $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "Group"
                    $processedConfig.GroupPolicies += $processedPolicy
                }
            }
        }

        # Process policies in the newer EntraRoles.Policies, AzureRoles.Policies, GroupRoles.Policies format
        if ($Config.PSObject.Properties['EntraRoles'] -and $Config.EntraRoles.PSObject.Properties['Policies'] -and $Config.EntraRoles.Policies) {
            Write-Verbose "Processing EntraRoles.Policies section"
            $processedConfig.EntraRolePolicies = @()

            foreach ($roleName in $Config.EntraRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.EntraRoles.Policies.$roleName

                # Determine if this is a template reference or inline policy
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    # Template reference
                    $policyDefinition = [PSCustomObject]@{
                        RoleName = $roleName
                        PolicySource = "template"
                        Template = $policyContent.Template
                    }
                } else {
                    # Inline policy - treat the content directly as the policy
                    $policyDefinition = [PSCustomObject]@{
                        RoleName = $roleName
                        PolicySource = "inline"
                        Policy = $policyContent
                    }
                }

                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType "EntraRole"
                $processedConfig.EntraRolePolicies += $processedPolicy
            }

            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies from EntraRoles.Policies"
        }

        if ($Config.PSObject.Properties['AzureRoles'] -and $Config.AzureRoles.PSObject.Properties['Policies'] -and $Config.AzureRoles.Policies) {
            Write-Verbose "Processing AzureRoles.Policies section"
            $processedConfig.AzureRolePolicies = @()

            foreach ($roleName in $Config.AzureRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.AzureRoles.Policies.$roleName

                # Extract scope if present
                $scope = $null
                if ($policyContent.PSObject.Properties['Scope'] -and $policyContent.Scope) {
                    $scope = $policyContent.Scope
                }

                # Determine if this is a template reference or inline policy
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    # Template reference
                    $policyDefinition = [PSCustomObject]@{
                        RoleName = $roleName
                        Scope = $scope
                        PolicySource = "template"
                        Template = $policyContent.Template
                    }
                } else {
                    # Inline policy - treat the content directly as the policy
                    # But exclude Scope from the policy content since it's metadata
                    $policyOnly = $policyContent | Select-Object -Property * -ExcludeProperty Scope
                    $policyDefinition = [PSCustomObject]@{
                        RoleName = $roleName
                        Scope = $scope
                        PolicySource = "inline"
                        Policy = $policyOnly
                    }
                }

                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType "AzureRole"
                $processedConfig.AzureRolePolicies += $processedPolicy
            }

            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies from AzureRoles.Policies"
        }

        if ($Config.PSObject.Properties['GroupRoles'] -and $Config.GroupRoles.PSObject.Properties['Policies'] -and $Config.GroupRoles.Policies) {
            Write-Verbose "Processing GroupRoles.Policies section"
            $processedConfig.GroupPolicies = @()

            foreach ($groupName in $Config.GroupRoles.Policies.PSObject.Properties.Name) {
                $policyContent = $Config.GroupRoles.Policies.$groupName

                # Determine if this is a template reference or inline policy
                if ($policyContent.PSObject.Properties['Template'] -and $policyContent.Template) {
                    # Template reference
                    $policyDefinition = [PSCustomObject]@{
                        GroupName = $groupName
                        PolicySource = "template"
                        Template = $policyContent.Template
                    }
                } else {
                    # Inline policy - treat the content directly as the policy
                    $policyDefinition = [PSCustomObject]@{
                        GroupName = $groupName
                        PolicySource = "inline"
                        Policy = $policyContent
                    }
                }

                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policyDefinition -Templates $policyTemplates -PolicyType "Group"
                $processedConfig.GroupPolicies += $processedPolicy
            }

            Write-Verbose "Processed $($processedConfig.GroupPolicies.Count) Group policies from GroupRoles.Policies"
        }

        # Copy existing configuration sections (assignments, etc.)
        $existingSections = @('AzureRoles', 'AzureRolesActive', 'EntraIDRoles', 'EntraIDRolesActive', 'GroupRoles', 'GroupRolesActive', 'ProtectedUsers', 'Assignments')
        foreach ($section in $existingSections) {
            if ($Config.PSObject.Properties[$section] -and $Config.$section) {
                $processedConfig[$section] = $Config.$section
            }
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
    <#
    .SYNOPSIS
        Resolves a single policy configuration based on its source type.

    .DESCRIPTION
        This function processes a policy definition and resolves it based on the PolicySource:
        - inline: Uses the Policy property directly
        - file: Loads policy from CSV file
        - template: Applies policy template

    .PARAMETER PolicyDefinition
        The policy definition object from the configuration

    .PARAMETER Templates
        Hashtable of available policy templates

    .PARAMETER PolicyType
        The type of policy (AzureRole, EntraRole, Group)

    .EXAMPLE
        $resolved = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $templates -PolicyType "AzureRole"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PolicyDefinition,

        [Parameter(Mandatory = $true)]
        [hashtable]$Templates,

        [Parameter(Mandatory = $true)]
        [ValidateSet("AzureRole", "EntraRole", "Group")]
        [string]$PolicyType
    )

    Write-Verbose "Resolving policy configuration for $PolicyType"

    # Convert PSCustomObject to hashtable for easier processing
    $resolvedPolicy = @{}
    foreach ($property in $PolicyDefinition.PSObject.Properties) {
        $resolvedPolicy[$property.Name] = $property.Value
    }

    # Validate required properties based on policy type
    switch ($PolicyType) {
        "AzureRole" {
            if (-not $PolicyDefinition.RoleName) {
                throw "AzureRole policy missing required property: RoleName"
            }
            if (-not $PolicyDefinition.Scope) {
                throw "AzureRole policy missing required property: Scope"
            }
        }
        "EntraRole" {
            if (-not $PolicyDefinition.RoleName) {
                throw "EntraRole policy missing required property: RoleName"
            }
        }
        "Group" {
            if (-not $PolicyDefinition.GroupId) {
                throw "Group policy missing required property: GroupId"
            }
            if (-not $PolicyDefinition.RoleName) {
                throw "Group policy missing required property: RoleName"
            }
        }
    }

    # Resolve policy based on source
    $policySource = $PolicyDefinition.policySource
    if (-not $policySource) {
        # Check if it's using the "template" property directly (new format)
        if ($PolicyDefinition.template) {
            $policySource = "template"
            Write-Verbose "Using template-based policy definition"
        } else {
            throw "Policy definition missing policySource property"
        }
    }

    switch ($policySource.ToLower()) {
        "inline" {
            Write-Verbose "Using inline policy definition"
            if (-not $PolicyDefinition.policy) {
                throw "Inline policy source specified but policy property is missing"
            }
            $resolvedPolicy.ResolvedPolicy = $PolicyDefinition.policy
        }

        "file" {
            Write-Verbose "Loading policy from file"
            if (-not $PolicyDefinition.policyFile) {
                throw "File policy source specified but policyFile property is missing"
            }

            if (-not (Test-Path $PolicyDefinition.policyFile)) {
                throw "Policy file not found: $($PolicyDefinition.policyFile)"
            }

            # Load CSV and convert to policy object
            $csvData = Import-Csv $PolicyDefinition.policyFile
            $resolvedPolicy.ResolvedPolicy = ConvertFrom-PolicyCSV -CsvData $csvData -PolicyType $PolicyType
        }

        "template" {
            Write-Verbose "Applying policy template"
            # Check both formats: PolicyTemplate (old) and template (new)
            $templateName = $PolicyDefinition.template
            if (-not $templateName) {
                $templateName = $PolicyDefinition.policyTemplate
            }
            if (-not $templateName) {
                throw "Template policy source specified but template property is missing"
            }
            if (-not $Templates.ContainsKey($templateName)) {
                throw "Policy template '$templateName' not found in configuration"
            }

            $resolvedPolicy.ResolvedPolicy = $Templates[$templateName]
        }

        default {
            throw "Unknown policy source: $policySource. Valid sources are: inline, file, template"
        }
    }

    # Validate resolved policy has required properties
    if (-not $resolvedPolicy.ResolvedPolicy) {
        throw "Failed to resolve policy configuration"
    }

    Write-Verbose "Policy configuration resolved successfully"
    return $resolvedPolicy
}

function ConvertFrom-PolicyCSV {
    <#
    .SYNOPSIS
        Converts CSV policy data to policy object format.

    .DESCRIPTION
        This function converts policy data from CSV format (as used by Export-PIM*Policy functions)
        to the inline policy object format used in the configuration.

    .PARAMETER CsvData
        The CSV data imported from policy file

    .PARAMETER PolicyType
        The type of policy being converted

    .EXAMPLE
        $policy = ConvertFrom-PolicyCSV -CsvData $csvData -PolicyType "AzureRole"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $CsvData,

        [Parameter(Mandatory = $true)]
        [ValidateSet("AzureRole", "EntraRole", "Group")]
        [string]$PolicyType
    )

    Write-Verbose "Converting CSV data to policy object for $PolicyType"

    if (-not $CsvData -or $CsvData.Count -eq 0) {
        throw "CSV data is empty or null"
    }

    # Take the first row (policies are typically single-row exports)
    $csvRow = $CsvData[0]

    $policy = @{}

    # Convert common CSV columns to policy properties
    if ($csvRow.ActivationDuration) {
        $policy.ActivationDuration = $csvRow.ActivationDuration
    }

    if ($csvRow.EnablementRules) {
        $policy.EnablementRules = $csvRow.EnablementRules -split ','
    }

    if ($csvRow.ApprovalRequired) {
        $policy.ApprovalRequired = [bool]::Parse($csvRow.ApprovalRequired)
    }

    if ($csvRow.Approvers) {
        # Parse approvers JSON if present
        try {
            $policy.Approvers = $csvRow.Approvers | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to parse approvers JSON: $($_.Exception.Message)"
        }
    }

    if ($csvRow.AllowPermanentEligibleAssignment) {
        $policy.AllowPermanentEligibleAssignment = [bool]::Parse($csvRow.AllowPermanentEligibleAssignment)
    }

    if ($csvRow.MaximumEligibleAssignmentDuration) {
        $policy.MaximumEligibleAssignmentDuration = $csvRow.MaximumEligibleAssignmentDuration
    }

    if ($csvRow.AllowPermanentActiveAssignment) {
        $policy.AllowPermanentActiveAssignment = [bool]::Parse($csvRow.AllowPermanentActiveAssignment)
    }

    if ($csvRow.MaximumActiveAssignmentDuration) {
        $policy.MaximumActiveAssignmentDuration = $csvRow.MaximumActiveAssignmentDuration
    }

    # Convert notification settings
    $policy.Notifications = @{
        Eligibility = @{
            Alert = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Eligibility_Alert_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Eligibility_Alert_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Eligibility_Alert_NotificationLevel) { "All" } else { $csvRow.Notification_Eligibility_Alert_NotificationLevel }
                Recipients = @()
            }
            Assignee = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Eligibility_Assignee_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Eligibility_Assignee_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Eligibility_Assignee_NotificationLevel) { "All" } else { $csvRow.Notification_Eligibility_Assignee_NotificationLevel }
                Recipients = @()
            }
            Approvers = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Eligibility_Approvers_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Eligibility_Approvers_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Eligibility_Approvers_NotificationLevel) { "All" } else { $csvRow.Notification_Eligibility_Approvers_NotificationLevel }
                Recipients = @()
            }
        }
        Active = @{
            Alert = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Active_Alert_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Active_Alert_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Active_Alert_NotificationLevel) { "All" } else { $csvRow.Notification_Active_Alert_NotificationLevel }
                Recipients = @()
            }
            Assignee = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Active_Assignee_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Active_Assignee_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Active_Assignee_NotificationLevel) { "All" } else { $csvRow.Notification_Active_Assignee_NotificationLevel }
                Recipients = @()
            }
            Approvers = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Active_Approvers_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Active_Approvers_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Active_Approvers_NotificationLevel) { "All" } else { $csvRow.Notification_Active_Approvers_NotificationLevel }
                Recipients = @()
            }
        }
        Activation = @{
            Alert = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Activation_Alert_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Activation_Alert_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Activation_Alert_NotificationLevel) { "All" } else { $csvRow.Notification_Activation_Alert_NotificationLevel }
                Recipients = @()
            }
            Assignee = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Activation_Assignee_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Activation_Assignee_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Activation_Assignee_NotificationLevel) { "All" } else { $csvRow.Notification_Activation_Assignee_NotificationLevel }
                Recipients = @()
            }
            Approvers = @{
                isDefaultRecipientEnabled = if ($null -eq $csvRow.Notification_Activation_Approvers_isDefaultRecipientEnabled) { $true } else { [bool]::Parse($csvRow.Notification_Activation_Approvers_isDefaultRecipientEnabled) }
                NotificationLevel = if ($null -eq $csvRow.Notification_Activation_Approvers_NotificationLevel) { "All" } else { $csvRow.Notification_Activation_Approvers_NotificationLevel }
                Recipients = @()
            }
        }
    }

    Write-Verbose "CSV conversion completed successfully"
    return $policy
}
