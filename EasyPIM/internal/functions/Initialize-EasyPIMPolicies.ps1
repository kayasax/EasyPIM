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
            # Convert PSCustomObject to hashtable for easier processing
            function Initialize-EasyPIMPolicies {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $true)] [PSCustomObject]$Config,
                    [Parameter(Mandatory = $false)] [ValidateSet('All','AzureRoles','EntraRoles','GroupRoles')] [string[]]$PolicyOperations = @('All')
                )
                Write-Verbose '[Core->Shared] Initialize-EasyPIMPolicies is shared-owned. Forwarding call (deprecated stub in core).'
                try {
                    return EasyPIM.Shared\Initialize-EasyPIMPolicies -Config $Config -PolicyOperations $PolicyOperations
                } catch {
                    throw "Initialize-EasyPIMPolicies is now provided by EasyPIM.Shared. Please import EasyPIM.Shared or use EasyPIM.Orchestrator which loads it automatically. Details: $($_.Exception.Message)"
                }
            }
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
