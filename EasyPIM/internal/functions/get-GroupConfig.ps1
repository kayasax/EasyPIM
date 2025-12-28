<#
    .Synopsis
        Get rules for the group $groupID
    .Description
        will convert the json rules to a PSCustomObject
    .Parameter id
        Id of the group to check
    .Parameter type
        type of role (owner or member)
    .Example
        PS> get-config -scope $scope -rolename role1

        Get the policy of the role role1 at the specified scope

    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function get-Groupconfig ( $id, $type) {

    try {
        $type = $type.ToLower()
        $endpoint = "policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$id' and scopeType eq 'Group' and roleDefinitionId eq '$type'&`$expand=policy(`$expand=rules)"
        $response = invoke-graph -Endpoint $endpoint

        if ($null -eq $response.value -or $response.value.Count -eq 0) {
            Write-Verbose "No policy assignment found for Group $id and Type $type"
            return $null
        }

        $policyId=$response.value[0].policyid
        #$response
        # Get config values in a new object:


        # Maximum end user activation duration in Hour (PT24H) // Max 24H in portal but can be greater
        $_activationDuration = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Expiration_EndUser_Assignment" }).maximumDuration
        # End user enablement rule (MultiFactorAuthentication, Justification, Ticketing)
        $_enablementRules = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Enablement_EndUser_Assignment" }).enabledRules
        # Active assignment requirement
        $_activeAssignmentRequirement = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Enablement_Admin_Assignment" }).enabledRules
        # Authentication context
        $_authenticationContext_Enabled = ($response.value[0].policy.rules | Where-Object { $_.id -eq "AuthenticationContext_EndUser_Assignment" }).isEnabled
        $_authenticationContext_value = ($response.value[0].policy.rules | Where-Object { $_.id -eq "AuthenticationContext_EndUser_Assignment" }).claimValue
        # approval required
        $_approvalrequired = $($response.value[0].policy.rules | Where-Object { $_.id -eq "Approval_EndUser_Assignment" }).setting.isapprovalrequired
        # approvers
        $approvers = $($response.value[0].policy.rules | Where-Object { $_.id -eq "Approval_EndUser_Assignment" }).setting.approvalStages.primaryApprovers
        if(( $approvers | Measure-Object | Select-Object -ExpandProperty Count) -gt 0){
            $approvers | ForEach-Object {
                if($_."@odata.type" -eq "#microsoft.graph.groupMembers"){
                    $_.userType = "group"
                    $_.id=$_.groupID
                }
                else{ #"@odata.type": "#microsoft.graph.singleUser",
                    $_.userType = "user"
                    $_.id=$_.userID
                }

                $_approvers += '@{"id"="' + $_.id + '";"description"="' + $_.description + '";"userType"="' + $_.userType + '"},'
            }
        }

        # permanent assignmnent eligibility
        $_eligibilityExpirationRequired = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Eligibility" }).isExpirationRequired
        if ($_eligibilityExpirationRequired -eq "true") {
            $_permanantEligibility = "false"
        }
        else {
            $_permanantEligibility = "true"
        }
        # maximum assignment eligibility duration
        $_maxAssignmentDuration = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Eligibility" }).maximumDuration

        # pemanent activation
        $_activeExpirationRequired = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Assignment" }).isExpirationRequired
        if ($_activeExpirationRequired -eq "true") {
            $_permanantActiveAssignment = "false"
        }
        else {
            $_permanantActiveAssignment = "true"
        }
        # maximum activation duration
        $_maxActiveAssignmentDuration = ($response.value[0].policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Assignment" }).maximumDuration

        #################
        # Notifications #
        #################

        # Notification Eligibility Alert (Send notifications when members are assigned as eligible to this role)
        $_Notification_Admin_Admin_Eligibility = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Admin_Admin_Eligibility" }
        # Notification Eligibility Assignee (Send notifications when members are assigned as eligible to this role: Notification to the assigned user (assignee))
        $_Notification_Eligibility_Assignee = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Requestor_Admin_Eligibility" }
        # Notification Eligibility Approvers (Send notifications when members are assigned as eligible to this role: request to approve a role assignment renewal/extension)
        $_Notification_Eligibility_Approvers = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Approver_Admin_Eligibility" }

        # Notification Active Assignment Alert (Send notifications when members are assigned as active to this role)
        $_Notification_Active_Alert = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Admin_Admin_Assignment" }
        # Notification Active Assignment Assignee (Send notifications when members are assigned as active to this role: Notification to the assigned user (assignee))
        $_Notification_Active_Assignee = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Requestor_Admin_Assignment" }
        # Notification Active Assignment Approvers (Send notifications when members are assigned as active to this role: Request to approve a role assignment renewal/extension)
        $_Notification_Active_Approvers = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Approver_Admin_Assignment" }

        # Notification Role Activation Alert (Send notifications when eligible members activate this role: Role activation alert)
        $_Notification_Activation_Alert = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Admin_EndUser_Assignment" }
        # Notification Activation Assignee (Send notifications when eligible members activate this role: Notification to the assigned user (assignee))
        $_Notification_Activation_Assignee = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Requestor_EndUser_Assignment" }
        # Notification Activation Approvers (Send notifications when eligible members activate this role: Request to approve a role activation)
        $_Notification_Activation_Approvers = $response.value[0].policy.rules | Where-Object { $_.id -eq "Notification_Approver_EndUser_Assignment" }

        $config = [PSCustomObject]@{
            RoleName                                                     = $type
            PolicyID                                                     = $policyId
            ActivationDuration                                           = $_activationDuration
            EnablementRules                                              = ($_enablementRules -join ',')
            ActiveAssignmentRules                                        = ($_activeAssignmentRequirement -join ',')
            AuthenticationContext_Enabled                                = $_authenticationContext_Enabled
            AuthenticationContext_Value                                  = $_authenticationContext_value
            ApprovalRequired                                             = $_approvalrequired
            Approvers                                                    = $_approvers
            AllowPermanentEligibleAssignment                             = $_permanantEligibility
            MaximumEligibleAssignmentDuration                            = $_maxAssignmentDuration
            AllowPermanentActiveAssignment                               = $_permanantActiveAssignment
            MaximumActiveAssignmentDuration                              = $_maxActiveAssignmentDuration
            Notification_Eligibility_Alert_isDefaultRecipientEnabled     = $($_Notification_Admin_Admin_Eligibility.setting.isDefaultRecipientsEnabled)
            Notification_Eligibility_Alert_NotificationLevel             = $($_Notification_Admin_Admin_Eligibility.setting.notificationLevel)
            Notification_Eligibility_Alert_Recipients                    = $($_Notification_Admin_Admin_Eligibility.setting.notificationRecipients -join ',')
            Notification_Eligibility_Assignee_isDefaultRecipientEnabled  = $($_Notification_Eligibility_Assignee.setting.isDefaultRecipientsEnabled)
            Notification_Eligibility_Assignee_NotificationLevel          = $($_Notification_Eligibility_Assignee.setting.notificationLevel)
            Notification_Eligibility_Assignee_Recipients                 = $($_Notification_Eligibility_Assignee.setting.notificationRecipients -join ',')
            Notification_Eligibility_Approvers_isDefaultRecipientEnabled = $($_Notification_Eligibility_Approvers.setting.isDefaultRecipientsEnabled)
            Notification_Eligibility_Approvers_NotificationLevel         = $($_Notification_Eligibility_Approvers.setting.notificationLevel)
            Notification_Eligibility_Approvers_Recipients                = $($_Notification_Eligibility_Approvers.setting.notificationRecipients -join ',')
            Notification_Active_Alert_isDefaultRecipientEnabled          = $($_Notification_Active_Alert.setting.isDefaultRecipientsEnabled)
            Notification_Active_Alert_NotificationLevel                  = $($_Notification_Active_Alert.setting.notificationLevel)
            Notification_Active_Alert_Recipients                         = $($_Notification_Active_Alert.setting.notificationRecipients -join ',')
            Notification_Active_Assignee_isDefaultRecipientEnabled       = $($_Notification_Active_Assignee.setting.isDefaultRecipientsEnabled)
            Notification_Active_Assignee_NotificationLevel               = $($_Notification_Active_Assignee.setting.notificationLevel)
            Notification_Active_Assignee_Recipients                      = $($_Notification_Active_Assignee.setting.notificationRecipients -join ',')
            Notification_Active_Approvers_isDefaultRecipientEnabled      = $($_Notification_Active_Approvers.setting.isDefaultRecipientsEnabled)
            Notification_Active_Approvers_NotificationLevel              = $($_Notification_Active_Approvers.setting.notificationLevel)
            Notification_Active_Approvers_Recipients                     = $($_Notification_Active_Approvers.setting.notificationRecipients -join ',')
            Notification_Activation_Alert_isDefaultRecipientEnabled      = $($_Notification_Activation_Alert.setting.isDefaultRecipientsEnabled)
            Notification_Activation_Alert_NotificationLevel              = $($_Notification_Activation_Alert.setting.notificationLevel)
            Notification_Activation_Alert_Recipients                     = $($_Notification_Activation_Alert.setting.notificationRecipients -join ',')
            Notification_Activation_Assignee_isDefaultRecipientEnabled   = $($_Notification_Activation_Assignee.setting.isDefaultRecipientsEnabled)
            Notification_Activation_Assignee_NotificationLevel           = $($_Notification_Activation_Assignee.setting.notificationLevel)
            Notification_Activation_Assignee_Recipients                  = $($_Notification_Activation_Assignee.setting.notificationRecipients -join ',')
            Notification_Activation_Approver_isDefaultRecipientEnabled   = $($_Notification_Activation_Approvers.setting.isDefaultRecipientsEnabled)
            Notification_Activation_Approver_NotificationLevel           = $($_Notification_Activation_Approvers.setting.notificationLevel)
            Notification_Activation_Approver_Recipients                  = $($_Notification_Activation_Approvers.setting.notificationRecipients -join ',')
        }
        return $config
    }
    catch {
        Mycatch $_
    }
}
