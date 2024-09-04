<#
    .Synopsis
        Get rules for the role $rolename
    .Description
        will convert the json rules to a PSCustomObject
    .Parameter rolename
        list of the role to check
    .Example
        PS> get-EntraRoleConfig -rolename "Global Administrator","Global Reader"

        Get the policy of the roles
     
    .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Get-EntraRoleConfig ($rolename) {
    try {
        
        # 1 Get roleID for $rolename
        $endpoint = "roleManagement/directory/roleDefinitions?`$filter=displayname eq '$rolename'"
        $response = invoke-graph -Endpoint $endpoint
        $roleID = $response.value.Id
        Write-Verbose "roleID = $roleID"
        if($null -eq $roleID){
            Throw "ERROR: Role $rolename not found"
            return
        }

        # 2 Get PIM policyID for that role
        $endpoint = "policies/roleManagementPolicyAssignments?`$filter=scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleID' and scopeId eq '/' "
        Write-Verbose "endpoint = $endpoint"
        $response = invoke-graph -Endpoint $endpoint
        $policyID = $response.value.policyID
        Write-Verbose "policyID = $policyID"

        # 3 Get the rules
        $endpoint = "policies/roleManagementPolicies/$policyID/rules"
        $response = invoke-graph -Endpoint $endpoint
        #$response.value.properties

      
        #$response
        # Get config values in a new object:

        # Maximum end user activation duration in Hour (PT24H) // Max 24H in portal but can be greater
        $_activationDuration = $($response.value | Where-Object { $_.id -eq "Expiration_EndUser_Assignment" }).maximumDuration # | Select-Object -ExpandProperty maximumduration
        # End user enablement rule (MultiFactorAuthentication, Justification, Ticketing)
        $_enablementRules = $($response.value | Where-Object { $_.id -eq "Enablement_EndUser_Assignment" }).enabledRules
        # Active assignment requirement
        $_activeAssignmentRequirement = $($response.value | Where-Object { $_.id -eq "Enablement_Admin_Assignment" }).enabledRules
        # Authentication context
        $_authenticationContext_Enabled = $($response.value | Where-Object { $_.id -eq "AuthenticationContext_EndUser_Assignment" }).isEnabled
        $_authenticationContext_value = $($response.value | Where-Object { $_.id -eq "AuthenticationContext_EndUser_Assignment" }).claimValue

        # approval required
        $_approvalrequired = $($response.value | Where-Object { $_.id -eq "Approval_EndUser_Assignment" }).setting.isapprovalrequired
        # approvers
        $approvers = $($response.value | Where-Object { $_.id -eq "Approval_EndUser_Assignment" }).setting.approvalStages.primaryApprovers
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
        $_eligibilityExpirationRequired = $($response.value | Where-Object { $_.id -eq "Expiration_Admin_Eligibility" }).isExpirationRequired
        if ($_eligibilityExpirationRequired -eq "true") {
            $_permanantEligibility = "false"
        }
        else {
            $_permanantEligibility = "true"
        }
        # maximum assignment eligibility duration
        $_maxAssignmentDuration = $($response.value | Where-Object { $_.id -eq "Expiration_Admin_Eligibility" }).maximumDuration
        
        # pemanent activation
        $_activeExpirationRequired = $($response.value | Where-Object { $_.id -eq "Expiration_Admin_Assignment" }).isExpirationRequired
        if ($_activeExpirationRequired -eq "true") {
            $_permanantActiveAssignment = "false"
        }
        else {
            $_permanantActiveAssignment = "true"
        }
        # maximum activation duration
        $_maxActiveAssignmentDuration = $($response.value | Where-Object { $_.id -eq "Expiration_Admin_Assignment" }).maximumDuration

        #################
        # Notifications #
        #################

        # Notification Eligibility Alert (Send notifications when members are assigned as eligible to this role)
        $_Notification_Admin_Admin_Eligibility = $response.value | Where-Object { $_.id -eq "Notification_Admin_Admin_Eligibility" }
        # Notification Eligibility Assignee (Send notifications when members are assigned as eligible to this role: Notification to the assigned user (assignee))
        $_Notification_Eligibility_Assignee = $response.value | Where-Object { $_.id -eq "Notification_Requestor_Admin_Eligibility" }
        # Notification Eligibility Approvers (Send notifications when members are assigned as eligible to this role: request to approve a role assignment renewal/extension)
        $_Notification_Eligibility_Approvers = $response.value | Where-Object { $_.id -eq "Notification_Approver_Admin_Eligibility" }

        # Notification Active Assignment Alert (Send notifications when members are assigned as active to this role)
        $_Notification_Active_Alert = $response.value | Where-Object { $_.id -eq "Notification_Admin_Admin_Assignment" }
        # Notification Active Assignment Assignee (Send notifications when members are assigned as active to this role: Notification to the assigned user (assignee))
        $_Notification_Active_Assignee = $response.value | Where-Object { $_.id -eq "Notification_Requestor_Admin_Assignment" }
        # Notification Active Assignment Approvers (Send notifications when members are assigned as active to this role: Request to approve a role assignment renewal/extension)
        $_Notification_Active_Approvers = $response.value | Where-Object { $_.id -eq "Notification_Approver_Admin_Assignment" }
        
        # Notification Role Activation Alert (Send notifications when eligible members activate this role: Role activation alert)
        $_Notification_Activation_Alert = $response.value | Where-Object { $_.id -eq "Notification_Admin_EndUser_Assignment" }
        # Notification Role Activation Assignee (Send notifications when eligible members activate this role: Notification to activated user (requestor))
        $_Notification_Activation_Assignee = $response.value | Where-Object { $_.id -eq "Notification_Requestor_EndUser_Assignment" }
        # Notification Role Activation Approvers (Send notifications when eligible members activate this role: Request to approve an activation)
        $_Notification_Activation_Approver = $response.value | Where-Object { $_.id -eq "Notification_Approver_EndUser_Assignment" }


        $config = [PSCustomObject]@{
            RoleName                                                     = $_
        roleID = $roleID
            PolicyID                                                     = $policyId
            ActivationDuration                                           = $_activationDuration
            EnablementRules                                              = $_enablementRules -join ','
            ActiveAssignmentRequirement                                  = $_activeAssignmentRequirement -join ','
            AuthenticationContext_Enabled                                = $_authenticationContext_Enabled
            AuthenticationContext_Value                                  = $_authenticationContext_value
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