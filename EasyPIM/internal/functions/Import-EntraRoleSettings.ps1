<#
    .Synopsis
        Import the settings from the csv file $path
    .Description
        Convert the csv back to policy rules
    .Parameter Path
        path to the csv file
    .Example
        PS> Import-EntraRoleSetting -path "c:\temp\myrole.csv"

        Import settings from file c:\temp\myrole.csv

    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Import-EntraRoleSettings  {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $path
    )



    # Mute console output for import banner
    log "Importing setting from $path" -noEcho
    if (!(test-path $path)) {
        throw "Operation failed, file $path cannot be found"
    }
    $csv = Import-Csv $path

    $csv | ForEach-Object {        $rules = @()
        $rules += Set-ActivationDuration $_.ActivationDuration -entrarole

        $enablementRules = $_.EnablementRules.Split(',')
        $rules += Set-ActivationRequirement $enablementRules -entraRole

        # Add missing ActiveAssignmentRequirement processing
        $activeAssignmentRequirements = $_.ActiveAssignmentRequirement.Split(',')
        $rules += Set-ActiveAssignmentRequirement $activeAssignmentRequirements -entraRole

        # Authentication Context (Issue #121): map CSV -> rule for Entra roles
        # Safely coerce CSV string to boolean and pass through value (supports formats like "c1" or "c1:Label")
        if ($_.PSObject.Properties['AuthenticationContext_Enabled']) {
            $authEnabledRaw = $_.AuthenticationContext_Enabled
            $authEnabled = $false
            if ($null -ne $authEnabledRaw -and $authEnabledRaw.ToString().Trim() -ne '') {
                try { $authEnabled = [System.Convert]::ToBoolean($authEnabledRaw) } catch { $authEnabled = $false }
            }
            $authValue = if ($_.PSObject.Properties['AuthenticationContext_Value']) { $_.AuthenticationContext_Value } else { $null }
            $rules += Set-AuthenticationContext $authEnabled $authValue -entraRole
        }

       # $approvers = @()
       # $approvers += $_.approvers

        $rules += Set-ApprovalFromCSV $_.ApprovalRequired $_.Approvers -entraRole


        $rules += Set-EligibilityAssignmentFromCSV $_.MaximumEligibleAssignmentDuration $_.AllowPermanentEligibleAssignment -entraRole

        $rules += Set-ActiveAssignmentFromCSV $_.MaximumActiveAssignmentDuration $_.AllowPermanentActiveAssignment -entraRole

        $Notification_EligibleAssignment_Alert = @{
            "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Alert_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Eligibility_Alert_notificationLevel;
            "Recipients"                = $_.Notification_Eligibility_Alert_Recipients.split(',')
        }
        $rules += Set-Notification_EligibleAssignment_Alert $Notification_EligibleAssignment_Alert -EntraRole

        $Notification_EligibleAssignment_Assignee = @{
            "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Assignee_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Eligibility_Assignee_notificationLevel;
            "Recipients"                = $_.Notification_Eligibility_Assignee_Recipients.split(',')
        }
        $rules += Set-Notification_EligibleAssignment_Assignee $Notification_EligibleAssignment_Assignee -entraRole

        $Notification_EligibleAssignment_Approver = @{
            "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Approvers_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Eligibility_Approvers_notificationLevel;
            "Recipients"                = $_.Notification_Eligibility_Approvers_Recipients.split(',')
        }
        $rules += Set-Notification_EligibleAssignment_Approver $Notification_EligibleAssignment_Approver -entraRole

        $Notification_Active_Alert = @{
            "isDefaultRecipientEnabled" = $_.Notification_Active_Alert_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Active_Alert_notificationLevel;
            "Recipients"                = $_.Notification_Active_Alert_Recipients.split(',')
        }
        $rules += Set-Notification_ActiveAssignment_Alert $Notification_Active_Alert -EntraRole

        $Notification_Active_Assignee = @{
            "isDefaultRecipientEnabled" = $_.Notification_Active_Assignee_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Active_Assignee_notificationLevel;
            "Recipients"                = $_.Notification_Active_Assignee_Recipients.split(',')
        }
        $rules += Set-Notification_ActiveAssignment_Assignee $Notification_Active_Assignee -entraRole

        $Notification_Active_Approvers = @{
            "isDefaultRecipientEnabled" = $_.Notification_Active_Approvers_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Active_Approvers_notificationLevel;
            "Recipients"                = $_.Notification_Active_Approvers_Recipients.split(',')
        }
        $rules += Set-Notification_ActiveAssignment_Approver $Notification_Active_Approvers -entraRole

        $Notification_Activation_Alert = @{
            "isDefaultRecipientEnabled" = $_.Notification_Activation_Alert_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Activation_Alert_notificationLevel;
            "Recipients"                = $_.Notification_Activation_Alert_Recipients.split(',')
        }
        $rules += Set-Notification_Activation_Alert $Notification_Activation_Alert -entraRole

        $Notification_Activation_Assignee = @{
            "isDefaultRecipientEnabled" = $_.Notification_Activation_Assignee_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Activation_Assignee_notificationLevel;
            "Recipients"                = $_.Notification_Activation_Assignee_Recipients.split(',')
        }
        $rules += Set-Notification_Activation_Assignee $Notification_Activation_Assignee -entraRole

        $Notification_Activation_Approver = @{
            "isDefaultRecipientEnabled" = $_.Notification_Activation_Approver_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Activation_Approver_notificationLevel;
            "Recipients"                = $_.Notification_Activation_Approver_Recipients.split(',')
        }
    $rules += Set-Notification_Activation_Approver $Notification_Activation_Approver -entraRole
        <#
        #>

        # patch the policy
        Update-EntraRolePolicy $_.policyID $($rules -join ',')
    }
}
