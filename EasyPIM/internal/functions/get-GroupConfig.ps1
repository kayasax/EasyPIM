<#Get-PIMGroupPolicyGet-PIMGroupPolicy
    .Synopsis
        Get rules for the group $groupID
    .Description
        will convert the json rules to a PSCustomObject
    .Parameter id
        Id of the group to check
    .Example
        PS> get-config -scope $scop -rolename role1

        Get the policy of the role role1 at the specified scope
     
    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function get-Groupconfig ( $id, $type) {

    try {
       
        $endpoint = "policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$id' and scopeType eq 'Group' and roleDefinitionId eq '$type'&`$expand=policy(`$expand=rules)"
        $response = invoke-graph -Endpoint $endpoint

        $policyId=$response.value.id   
        #$response
        # Get config values in a new object:

        # Maximum end user activation duration in Hour (PT24H) // Max 24H in portal but can be greater
        $_activationDuration = $response.value.policy.rules | Where-Object { $_.id -eq "Expiration_EndUser_Assignment" } | Select-Object -ExpandProperty maximumduration
        # End user enablement rule (MultiFactorAuthentication, Justification, Ticketing)
        $_enablementRules = $response.value.policy.rules | Where-Object { $_.id -eq "Enablement_EndUser_Assignment" } | Select-Object -expand enabledRules
        # approval required
        $_approvalrequired = $($response.value.policy.rules | Where-Object { $_.id -eq "Approval_EndUser_Assignment" }).setting.isapprovalrequired
        # approvers
        $approvers = $($response.value.policy.rules | Where-Object { $_.id -eq "Approval_EndUser_Assignment" }).setting.approvalStages.primaryApprovers
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
        $_eligibilityExpirationRequired = $response.value.policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Eligibility" } | Select-Object -expand isExpirationRequired
        if ($_eligibilityExpirationRequired -eq "true") {
            $_permanantEligibility = "false"
        }
        else {
            $_permanantEligibility = "true"
        }
        # maximum assignment eligibility duration
        $_maxAssignmentDuration = $response.value.policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Eligibility" } | Select-Object -expand maximumDuration
        
        # pemanent activation
        $_activeExpirationRequired = $response.value.policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Assignment" } | Select-Object -expand isExpirationRequired
        if ($_activeExpirationRequired -eq "true") {
            $_permanantActiveAssignment = "false"
        }
        else {
            $_permanantActiveAssignment = "true"
        }
        # maximum activation duration
        $_maxActiveAssignmentDuration = $response.value.policy.rules | Where-Object { $_.id -eq "Expiration_Admin_Assignment" } | Select-Object -expand maximumDuration

        #################
        # Notifications #
        #################

        # Notification Eligibility Alert (Send notifications when members are assigned as eligible to this role)
        $_Notification_Admin_Admin_Eligibility = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Admin_Admin_Eligibility" }
        # Notification Eligibility Assignee (Send notifications when members are assigned as eligible to this role: Notification to the assigned user (assignee))
        $_Notification_Eligibility_Assignee = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Requestor_Admin_Eligibility" }
        # Notification Eligibility Approvers (Send notifications when members are assigned as eligible to this role: request to approve a role assignment renewal/extension)
        $_Notification_Eligibility_Approvers = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Approver_Admin_Eligibility" }

        # Notification Active Assignment Alert (Send notifications when members are assigned as active to this role)
        $_Notification_Active_Alert = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Admin_Admin_Assignment" }
        # Notification Active Assignment Assignee (Send notifications when members are assigned as active to this role: Notification to the assigned user (assignee))
        $_Notification_Active_Assignee = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Requestor_Admin_Assignment" }
        # Notification Active Assignment Approvers (Send notifications when members are assigned as active to this role: Request to approve a role assignment renewal/extension)
        $_Notification_Active_Approvers = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Approver_Admin_Assignment" }
        
        # Notification Role Activation Alert (Send notifications when eligible members activate this role: Role activation alert)
        $_Notification_Activation_Alert = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Admin_EndUser_Assignment" }
        # Notification Role Activation Assignee (Send notifications when eligible members activate this role: Notification to activated user (requestor))
        $_Notification_Activation_Assignee = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Requestor_EndUser_Assignment" }
        # Notification Role Activation Approvers (Send notifications when eligible members activate this role: Request to approve an activation)
        $_Notification_Activation_Approver = $response.value.policy.rules | Where-Object { $_.id -eq "Notification_Approver_EndUser_Assignment" }


        $config = [PSCustomObject]@{
            
            PolicyID                                                     = $policyId
            ActivationDuration                                           = $_activationDuration
            EnablementRules                                              = $_enablementRules -join ','
            ApprovalRequired                                             = $_approvalrequired
            Approvers                                                    = $_approvers -join ','
            AllowPermanentEligibleAssignment                             = $_permanantEligibility
            MaximumEligibleAssignmentDuration                            = $_maxAssignmentDuration
            AllowPermanentActiveAssignment                               = $_permanantActiveAssignment
            MaximumActiveAssignmentDuration                              = $_maxActiveAssignmentDuration
            Notification_Eligibility_Alert_isDefaultRecipientEnabled     = $($_Notification_Admin_Admin_Eligibility.isDefaultRecipientsEnabled)
            Notification_Eligibility_Alert_NotificationLevel             = $($_Notification_Admin_Admin_Eligibility.notificationLevel)
            Notification_Eligibility_Alert_Recipients                    = $($_Notification_Admin_Admin_Eligibility.notificationRecipients) -join ','
            Notification_Eligibility_Assignee_isDefaultRecipientEnabled  = $($_Notification_Eligibility_Assignee.isDefaultRecipientsEnabled)
            Notification_Eligibility_Assignee_NotificationLevel          = $($_Notification_Eligibility_Assignee.NotificationLevel)
            Notification_Eligibility_Assignee_Recipients                 = $($_Notification_Eligibility_Assignee.notificationRecipients) -join ','
            Notification_Eligibility_Approvers_isDefaultRecipientEnabled = $($_Notification_Eligibility_Approvers.isDefaultRecipientsEnabled)
            Notification_Eligibility_Approvers_NotificationLevel         = $($_Notification_Eligibility_Approvers.NotificationLevel)
            Notification_Eligibility_Approvers_Recipients                = $($_Notification_Eligibility_Approvers.notificationRecipients -join ',')
            Notification_Active_Alert_isDefaultRecipientEnabled          = $($_Notification_Active_Alert.isDefaultRecipientsEnabled)
            Notification_Active_Alert_NotificationLevel                  = $($_Notification_Active_Alert.notificationLevel)
            Notification_Active_Alert_Recipients                         = $($_Notification_Active_Alert.notificationRecipients -join ',')
            Notification_Active_Assignee_isDefaultRecipientEnabled       = $($_Notification_Active_Assignee.isDefaultRecipientsEnabled)
            Notification_Active_Assignee_NotificationLevel               = $($_Notification_Active_Assignee.notificationLevel)
            Notification_Active_Assignee_Recipients                      = $($_Notification_Active_Assignee.notificationRecipients -join ',')
            Notification_Active_Approvers_isDefaultRecipientEnabled      = $($_Notification_Active_Approvers.isDefaultRecipientsEnabled)
            Notification_Active_Approvers_NotificationLevel              = $($_Notification_Active_Approvers.notificationLevel)
            Notification_Active_Approvers_Recipients                     = $($_Notification_Active_Approvers.notificationRecipients -join ',')
            Notification_Activation_Alert_isDefaultRecipientEnabled      = $($_Notification_Activation_Alert.isDefaultRecipientsEnabled)
            Notification_Activation_Alert_NotificationLevel              = $($_Notification_Activation_Alert.NotificationLevel)
            Notification_Activation_Alert_Recipients                     = $($_Notification_Activation_Alert.NotificationRecipients -join ',')
            Notification_Activation_Assignee_isDefaultRecipientEnabled   = $($_Notification_Activation_Assignee.isDefaultRecipientsEnabled)
            Notification_Activation_Assignee_NotificationLevel           = $($_Notification_Activation_Assignee.NotificationLevel)
            Notification_Activation_Assignee_Recipients                  = $($_Notification_Activation_Assignee.NotificationRecipients -join ',')
            Notification_Activation_Approver_isDefaultRecipientEnabled   = $($_Notification_Activation_Approver.isDefaultRecipientsEnabled)
            Notification_Activation_Approver_NotificationLevel           = $($_Notification_Activation_Approver.NotificationLevel)
            Notification_Activation_Approver_Recipients                  = $($_Notification_Activation_Approver.NotificationRecipients -join ',')
        }
        return $config
    }
    catch {
        Mycatch $_
    }
}