function get-config ($scope, $rolename, $copyFrom = $null) {

    $ARMhost = "https://management.azure.com"
    $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"
    try {

        
        # 1 Get ID of the role $rolename assignable at the provided scope
        $restUri = "$ARMendpoint/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$rolename'"

        write-verbose " #1 Get role definition for the role $rolename assignable at the scope $scope at $restUri"
        $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
        $roleID = $response.value.id
        #if ($null -eq $roleID) { throw "An exception occured : can't find a roleID for $rolename at scope $scope" }
        Write-Verbose ">> RodeId = $roleID"

        if( ($roleID -eq "") -or ($null -eq $roleID)){
            Log "Error getting config of $rolename"
            #continue with other roles
             return
        }

        # 2  get the role assignment for the roleID found at #1
        $restUri = "$ARMendpoint/roleManagementPolicyAssignments?api-version=2020-10-01&`$filter=roleDefinitionId eq '$roleID'"
        write-verbose " #2 Get the Assignment for $rolename at $restUri"
        $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
        $policyId = $response.value.properties.policyId #.split('/')[-1] 
        Write-Verbose ">> policy ID = $policyId"

        # 3 get the role policy for the policyID found in #2
        $restUri = "$ARMhost/$policyId/?api-version=2020-10-01"
        write-verbose " #3 get role policy at $restUri"
        $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false

        #Write-Verbose "copy from = $copyFrom"
        if ($null -ne $copyFrom) {
            Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false -OutFile "$_scriptPath\temp.json"
            $response = Get-Content "$_scriptPath\temp.json"
            $response = $response -replace '^.*"rules":\['
            $response = $response -replace '\],"effectiveRules":.*$'
            Remove-Item "$_scriptPath\temp.json" 
            return $response
        }
      
        #$response
        # Get config values in a new object:

        # Maximum end user activation duration in Hour (PT24H) // Max 24H in portal but can be greater
        $_activationDuration = $response.properties.rules | ? { $_.id -eq "Expiration_EndUser_Assignment" } | select -ExpandProperty maximumduration
        # End user enablement rule (MultiFactorAuthentication, Justification, Ticketing)
        $_enablementRules = $response.properties.rules | ? { $_.id -eq "Enablement_EndUser_Assignment" } | select -expand enabledRules
        # approval required 
        $_approvalrequired = $($response.properties.rules | ? { $_.id -eq "Approval_EndUser_Assignment" }).setting.isapprovalrequired
        # approvers 
        $approvers = $($response.properties.rules | ? { $_.id -eq "Approval_EndUser_Assignment" }).setting.approvalStages.primaryApprovers
        $approvers | % {
            $_approvers += '@{"id"="' + $_.id + '";"description"="' + $_.description + '";"userType"="' + $_.userType + '"},'
        }

        # permanent assignmnent eligibility
        $_eligibilityExpirationRequired = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Eligibility" } | Select-Object -expand isExpirationRequired
        if ($_eligibilityExpirationRequired -eq "true") { 
            $_permanantEligibility = "false"
        }
        else { 
            $_permanantEligibility = "true"
        }
        # maximum assignment eligibility duration
        $_maxAssignmentDuration = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Eligibility" } | Select-Object -expand maximumDuration
        
        # pemanent activation
        $_activeExpirationRequired = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Assignment" } | Select-Object -expand isExpirationRequired
        if ($_activeExpirationRequired -eq "true") { 
            $_permanantActiveAssignment = "false"
        }
        else { 
            $_permanantActiveAssignment = "true"
        }
        # maximum activation duration
        $_maxActiveAssignmentDuration = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Assignment" } | Select-Object -expand maximumDuration

        #################
        # Notifications #
        #################

        # Notification Eligibility Alert (Send notifications when members are assigned as eligible to this role)
        $_Notification_Admin_Admin_Eligibility = $response.properties.rules | ? { $_.id -eq "Notification_Admin_Admin_Eligibility" } 
        # Notification Eligibility Assignee (Send notifications when members are assigned as eligible to this role: Notification to the assigned user (assignee))
        $_Notification_Eligibility_Assignee = $response.properties.rules | ? { $_.id -eq "Notification_Requestor_Admin_Eligibility" } 
        # Notification Eligibility Approvers (Send notifications when members are assigned as eligible to this role: request to approve a role assignment renewal/extension)
        $_Notification_Eligibility_Approvers = $response.properties.rules | ? { $_.id -eq "Notification_Approver_Admin_Eligibility" }

        # Notification Active Assignment Alert (Send notifications when members are assigned as active to this role)
        $_Notification_Active_Alert = $response.properties.rules | ? { $_.id -eq "Notification_Admin_Admin_Assignment" } 
        # Notification Active Assignment Assignee (Send notifications when members are assigned as active to this role: Notification to the assigned user (assignee))
        $_Notification_Active_Assignee = $response.properties.rules | ? { $_.id -eq "Notification_Requestor_Admin_Assignment" } 
        # Notification Active Assignment Approvers (Send notifications when members are assigned as active to this role: Request to approve a role assignment renewal/extension)
        $_Notification_Active_Approvers = $response.properties.rules | ? { $_.id -eq "Notification_Approver_Admin_Assignment" } 
        
        # Notification Role Activation Alert (Send notifications when eligible members activate this role: Role activation alert)
        $_Notification_Activation_Alert = $response.properties.rules | ? { $_.id -eq "Notification_Admin_EndUser_Assignment" } 
        # Notification Role Activation Assignee (Send notifications when eligible members activate this role: Notification to activated user (requestor))
        $_Notification_Activation_Assignee = $response.properties.rules | ? { $_.id -eq "Notification_Requestor_EndUser_Assignment" } 
        # Notification Role Activation Approvers (Send notifications when eligible members activate this role: Request to approve an activation)
        $_Notification_Activation_Approvers = $response.properties.rules | ? { $_.id -eq "Notification_Approver_EndUser_Assignment" } 


        $config = [PSCustomObject]@{
            RoleName                                                     = $_
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
            Notification_Activation_Approvers_isDefaultRecipientEnabled  = $($_Notification_Activation_Approvers.isDefaultRecipientsEnabled)
            Notification_Activation_Approvers_NotificationLevel          = $($_Notification_Activation_Approvers.NotificationLevel)
            Notification_Activation_Approvers_Recipients                 = $($_Notification_Activation_Approvers.NotificationRecipients -join ',')
        }
        return $config
    }
    catch {
        Mycatch $_
    }
}