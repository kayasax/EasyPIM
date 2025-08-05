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
        [hashtable]$Config
    )

    Write-Verbose "Starting Initialize-EasyPIMPolicies"
    
    try {
        $processedConfig = @{}
        
        # Initialize policy templates if they exist
        $policyTemplates = @{}
        if ($Config.ContainsKey('PolicyTemplates')) {
            $policyTemplates = $Config.PolicyTemplates
            Write-Verbose "Found $($policyTemplates.Keys.Count) policy templates"
        }

        # Process Azure Role Policies
        if ($Config.ContainsKey('AzureRolePolicies')) {
            Write-Verbose "Processing Azure Role Policies"
            $processedConfig.AzureRolePolicies = @()
            
            foreach ($policy in $Config.AzureRolePolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "AzureRole"
                $processedConfig.AzureRolePolicies += $processedPolicy
            }
            
            Write-Verbose "Processed $($processedConfig.AzureRolePolicies.Count) Azure Role policies"
        }

        # Process Entra Role Policies
        if ($Config.ContainsKey('EntraRolePolicies')) {
            Write-Verbose "Processing Entra Role Policies"
            $processedConfig.EntraRolePolicies = @()
            
            foreach ($policy in $Config.EntraRolePolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "EntraRole"
                $processedConfig.EntraRolePolicies += $processedPolicy
            }
            
            Write-Verbose "Processed $($processedConfig.EntraRolePolicies.Count) Entra Role policies"
        }

        # Process Group Policies
        if ($Config.ContainsKey('GroupPolicies')) {
            Write-Verbose "Processing Group Policies"
            $processedConfig.GroupPolicies = @()
            
            foreach ($policy in $Config.GroupPolicies) {
                $processedPolicy = Resolve-PolicyConfiguration -PolicyDefinition $policy -Templates $policyTemplates -PolicyType "Group"
                $processedConfig.GroupPolicies += $processedPolicy
            }
            
            Write-Verbose "Processed $($processedConfig.GroupPolicies.Count) Group policies"
        }

        # Copy existing configuration sections (assignments, etc.)
        $existingSections = @('AzureRoles', 'AzureRolesActive', 'EntraIDRoles', 'EntraIDRolesActive', 'GroupRoles', 'GroupRolesActive', 'ProtectedUsers')
        foreach ($section in $existingSections) {
            if ($Config.ContainsKey($section)) {
                $processedConfig[$section] = $Config[$section]
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
        [hashtable]$PolicyDefinition,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Templates,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("AzureRole", "EntraRole", "Group")]
        [string]$PolicyType
    )

    Write-Verbose "Resolving policy configuration for $PolicyType"
    
    $resolvedPolicy = $PolicyDefinition.Clone()
    
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
    $policySource = $PolicyDefinition.PolicySource
    if (-not $policySource) {
        throw "Policy definition missing PolicySource property"
    }

    switch ($policySource.ToLower()) {
        "inline" {
            Write-Verbose "Using inline policy definition"
            if (-not $PolicyDefinition.Policy) {
                throw "Inline policy source specified but Policy property is missing"
            }
            $resolvedPolicy.ResolvedPolicy = $PolicyDefinition.Policy
        }
        
        "file" {
            Write-Verbose "Loading policy from file"
            if (-not $PolicyDefinition.PolicyFile) {
                throw "File policy source specified but PolicyFile property is missing"
            }
            
            if (-not (Test-Path $PolicyDefinition.PolicyFile)) {
                throw "Policy file not found: $($PolicyDefinition.PolicyFile)"
            }
            
            # Load CSV and convert to policy object
            $csvData = Import-Csv $PolicyDefinition.PolicyFile
            $resolvedPolicy.ResolvedPolicy = ConvertFrom-PolicyCSV -CsvData $csvData -PolicyType $PolicyType
        }
        
        "template" {
            Write-Verbose "Applying policy template"
            if (-not $PolicyDefinition.PolicyTemplate) {
                throw "Template policy source specified but PolicyTemplate property is missing"
            }
            
            $templateName = $PolicyDefinition.PolicyTemplate
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
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Eligibility_Alert_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Eligibility_Alert_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Eligibility_Alert_NotificationLevel) ? "All" : $csvRow.Notification_Eligibility_Alert_NotificationLevel
                Recipients = @()
            }
            Assignee = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Eligibility_Assignee_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Eligibility_Assignee_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Eligibility_Assignee_NotificationLevel) ? "All" : $csvRow.Notification_Eligibility_Assignee_NotificationLevel
                Recipients = @()
            }
            Approvers = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Eligibility_Approvers_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Eligibility_Approvers_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Eligibility_Approvers_NotificationLevel) ? "All" : $csvRow.Notification_Eligibility_Approvers_NotificationLevel
                Recipients = @()
            }
        }
        Active = @{
            Alert = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Active_Alert_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Active_Alert_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Active_Alert_NotificationLevel) ? "All" : $csvRow.Notification_Active_Alert_NotificationLevel
                Recipients = @()
            }
            Assignee = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Active_Assignee_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Active_Assignee_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Active_Assignee_NotificationLevel) ? "All" : $csvRow.Notification_Active_Assignee_NotificationLevel
                Recipients = @()
            }
            Approvers = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Active_Approvers_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Active_Approvers_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Active_Approvers_NotificationLevel) ? "All" : $csvRow.Notification_Active_Approvers_NotificationLevel
                Recipients = @()
            }
        }
        Activation = @{
            Alert = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Activation_Alert_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Activation_Alert_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Activation_Alert_NotificationLevel) ? "All" : $csvRow.Notification_Activation_Alert_NotificationLevel
                Recipients = @()
            }
            Assignee = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Activation_Assignee_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Activation_Assignee_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Activation_Assignee_NotificationLevel) ? "All" : $csvRow.Notification_Activation_Assignee_NotificationLevel
                Recipients = @()
            }
            Approvers = @{
                isDefaultRecipientEnabled = [bool]::Parse(($null -eq $csvRow.Notification_Activation_Approvers_isDefaultRecipientEnabled) ? "true" : $csvRow.Notification_Activation_Approvers_isDefaultRecipientEnabled)
                NotificationLevel = ($null -eq $csvRow.Notification_Activation_Approvers_NotificationLevel) ? "All" : $csvRow.Notification_Activation_Approvers_NotificationLevel
                Recipients = @()
            }
        }
    }

    Write-Verbose "CSV conversion completed successfully"
    return $policy
}
