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

    # Local helper to safely split comma-delimited strings, returning an empty array for null/empty
    function Split-OrEmpty([object]$value) {
        $s = [string]$value
        if ([string]::IsNullOrWhiteSpace($s)) { return @() }
        return ($s -split ',')
    }

    $csv | ForEach-Object {
        $rules = @()

        # Determine Authentication Context early for downstream rule decisions
        $authEnabled = $false
        $authValue = $null
        if ($_.PSObject.Properties['AuthenticationContext_Enabled']) {
            $authEnabledRaw = $_.AuthenticationContext_Enabled
            if ($null -ne $authEnabledRaw -and $authEnabledRaw.ToString().Trim() -ne '') {
                try { $authEnabled = [System.Convert]::ToBoolean($authEnabledRaw) } catch { $authEnabled = $false }
            }
            if ($_.PSObject.Properties['AuthenticationContext_Value']) { $authValue = $_.AuthenticationContext_Value }
        }

        $rules += Set-ActivationDuration $_.ActivationDuration -entrarole

        # Filter enablement rules for EndUser Assignment (allowed: MultiFactorAuthentication, Justification, Ticketing)
        $enablementRules = Split-OrEmpty $_.EnablementRules
        if ($enablementRules) {
            $allowedEndUser = @('MultiFactorAuthentication','Justification','Ticketing')
            $enablementRules = @($enablementRules | Where-Object { $allowedEndUser -contains $_ })
            # If Authentication Context is enabled, optionally remove MFA to avoid MfaAndAcrsConflict
            # Honor global preference: set $global:EasyPIM_AutoResolveMfaAcrConflict = $false to keep MFA alongside Auth Context (may error in Graph)
            $autoResolve = if ($null -ne $global:EasyPIM_AutoResolveMfaAcrConflict) { [bool]$global:EasyPIM_AutoResolveMfaAcrConflict } else { $true }
            if ($authEnabled -eq $true -and $autoResolve) {
                if ($enablementRules -contains 'MultiFactorAuthentication') {
                    Write-Verbose "Removing 'MultiFactorAuthentication' from Enablement_EndUser_Assignment because Authentication Context is enabled (avoids MfaAndAcrsConflict)"
                    $enablementRules = @($enablementRules | Where-Object { $_ -ne 'MultiFactorAuthentication' })
                }
            }
        }
        if ($enablementRules.Count -gt 0) {
            $rules += Set-ActivationRequirement $enablementRules -entraRole
        } else {
            Write-Verbose 'Skipping Enablement_EndUser_Assignment (no allowed end-user rules)'
        }

        # Filter enablement rules for Admin Assignment (allowed: Justification, Ticketing)
        $activeAssignmentRequirements = Split-OrEmpty $_.ActiveAssignmentRequirement
        if ($activeAssignmentRequirements) {
            $allowedAdmin = @('Justification','Ticketing')
            $activeAssignmentRequirements = @($activeAssignmentRequirements | Where-Object { $allowedAdmin -contains $_ })
        }
        if ($activeAssignmentRequirements.Count -gt 0) {
            $rules += Set-ActiveAssignmentRequirement $activeAssignmentRequirements -entraRole
        } else {
            Write-Verbose 'Skipping Enablement_Admin_Assignment (no allowed admin rules)'
        }

        # Authentication Context (Issue #121): map CSV -> rule for Entra roles
        if ($_.PSObject.Properties['AuthenticationContext_Enabled']) {
            $rules += Set-AuthenticationContext $authEnabled $authValue -entraRole
        }

       # $approvers = @()
       # $approvers += $_.approvers

        $rules += Set-ApprovalFromCSV $_.ApprovalRequired $_.Approvers -entraRole


        $rules += Set-EligibilityAssignmentFromCSV $_.MaximumEligibleAssignmentDuration $_.AllowPermanentEligibleAssignment -entraRole

        $rules += Set-ActiveAssignmentFromCSV $_.MaximumActiveAssignmentDuration $_.AllowPermanentActiveAssignment -entraRole

        if ($_.PSObject.Properties['Notification_Eligibility_Alert_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Eligibility_Alert_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Eligibility_Alert_Recipients']) {
            $Notification_EligibleAssignment_Alert = @{
                "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Alert_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Eligibility_Alert_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Eligibility_Alert_Recipients)
            }
            $rules += Set-Notification_EligibleAssignment_Alert $Notification_EligibleAssignment_Alert -EntraRole
        }

        if ($_.PSObject.Properties['Notification_Eligibility_Assignee_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Eligibility_Assignee_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Eligibility_Assignee_Recipients']) {
            $Notification_EligibleAssignment_Assignee = @{
                "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Assignee_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Eligibility_Assignee_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Eligibility_Assignee_Recipients)
            }
            $rules += Set-Notification_EligibleAssignment_Assignee $Notification_EligibleAssignment_Assignee -entraRole
        }

        if ($_.PSObject.Properties['Notification_Eligibility_Approvers_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Eligibility_Approvers_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Eligibility_Approvers_Recipients']) {
            $Notification_EligibleAssignment_Approver = @{
                "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Approvers_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Eligibility_Approvers_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Eligibility_Approvers_Recipients)
            }
            $rules += Set-Notification_EligibleAssignment_Approver $Notification_EligibleAssignment_Approver -entraRole
        }

        if ($_.PSObject.Properties['Notification_Active_Alert_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Active_Alert_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Active_Alert_Recipients']) {
            $Notification_Active_Alert = @{
                "isDefaultRecipientEnabled" = $_.Notification_Active_Alert_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Active_Alert_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Active_Alert_Recipients)
            }
            $rules += Set-Notification_ActiveAssignment_Alert $Notification_Active_Alert -EntraRole
        }

        if ($_.PSObject.Properties['Notification_Active_Assignee_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Active_Assignee_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Active_Assignee_Recipients']) {
            $Notification_Active_Assignee = @{
                "isDefaultRecipientEnabled" = $_.Notification_Active_Assignee_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Active_Assignee_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Active_Assignee_Recipients)
            }
            $rules += Set-Notification_ActiveAssignment_Assignee $Notification_Active_Assignee -entraRole
        }

        if ($_.PSObject.Properties['Notification_Active_Approvers_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Active_Approvers_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Active_Approvers_Recipients']) {
            $Notification_Active_Approvers = @{
                "isDefaultRecipientEnabled" = $_.Notification_Active_Approvers_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Active_Approvers_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Active_Approvers_Recipients)
            }
            $rules += Set-Notification_ActiveAssignment_Approver $Notification_Active_Approvers -entraRole
        }

        if ($_.PSObject.Properties['Notification_Activation_Alert_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Activation_Alert_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Activation_Alert_Recipients']) {
            $Notification_Activation_Alert = @{
                "isDefaultRecipientEnabled" = $_.Notification_Activation_Alert_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Activation_Alert_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Activation_Alert_Recipients)
            }
            $rules += Set-Notification_Activation_Alert $Notification_Activation_Alert -entraRole
        }

        if ($_.PSObject.Properties['Notification_Activation_Assignee_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Activation_Assignee_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Activation_Assignee_Recipients']) {
            $Notification_Activation_Assignee = @{
                "isDefaultRecipientEnabled" = $_.Notification_Activation_Assignee_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Activation_Assignee_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Activation_Assignee_Recipients)
            }
            $rules += Set-Notification_Activation_Assignee $Notification_Activation_Assignee -entraRole
        }

        if ($_.PSObject.Properties['Notification_Activation_Approver_isDefaultRecipientEnabled'] -or
            $_.PSObject.Properties['Notification_Activation_Approver_notificationLevel'] -or
            $_.PSObject.Properties['Notification_Activation_Approver_Recipients']) {
            $Notification_Activation_Approver = @{
                "isDefaultRecipientEnabled" = $_.Notification_Activation_Approver_isDefaultRecipientEnabled;
                "notificationLevel"         = $_.Notification_Activation_Approver_notificationLevel;
                "Recipients"                = (Split-OrEmpty $_.Notification_Activation_Approver_Recipients)
            }
            $rules += Set-Notification_Activation_Approver $Notification_Activation_Approver -entraRole
        }
        <#
        #>

        # Resolve policy ID if missing in CSV
        $policyIdToUse = $_.PolicyID
        if ([string]::IsNullOrWhiteSpace([string]$policyIdToUse)) {
            $roleId = $_.roleID
            if ([string]::IsNullOrWhiteSpace([string]$roleId)) {
                $rn = [string]$_.RoleName
                if (-not [string]::IsNullOrWhiteSpace($rn)) {
                    # Escape single quotes in role name for OData
                    $rnEsc = $rn -replace "'", "''"
                    $ep = "roleManagement/directory/roleDefinitions?`$filter=displayname eq '$rnEsc'"
                    $resp = invoke-graph -Endpoint $ep -ErrorAction Stop
                    $roleId = $resp.value.id
                }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$roleId)) {
                $assignEp = "policies/roleManagementPolicyAssignments?`$filter=scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleId' and scopeId eq '/' "
                $assign = invoke-graph -Endpoint $assignEp -ErrorAction Stop
                $policyIdToUse = $assign.value.policyId
                if (-not $policyIdToUse) { $policyIdToUse = $assign.value.policyID }
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$policyIdToUse)) { throw "Unable to resolve PolicyID for RoleName='$($_.RoleName)'" }

        # patch the policy
        Update-EntraRolePolicy $policyIdToUse $($rules -join ',')
    }
}
