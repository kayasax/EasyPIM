﻿<#
      .Synopsis
       Set the setting of the role $rolename at the subscription scope where subscription = $subscription
      .Description
       Get the setting of the role $rolename at the subscription scope where subscription = $subscription
 
      .Example
        PS> Set-PIMAzureResourcePolicy -tenantID $tenantID -subscriptionID $subscriptionID -rolename webmaster -ActivationDuration "PT8H"

        Limit the maximum PIM activation duration to 8h
      .EXAMPLE
        PS> Set-PIMAzureResourcePolicy -TenantID $tenantID -SubscriptionId $subscriptionID -rolename "contributor" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true

        Require activation approval and set John as an approver


      .Link
     
      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Set-PIMAzureResourcePolicy {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        #subscriptionID
        $subscriptionID,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.String[]]
        #list of role to update
        $rolename,

        [System.String]
        # Maximum activation duration
        $ActivationDuration = $null,
       
        [Parameter(HelpMessage = "Accepted values: 'None' or any combination of these options (Case SENSITIVE):  'Justification, 'MultiFactorAuthentication', 'Ticketing'")]
        [ValidateScript({
                # accepted values: "None","Justification", "MultiFactorAuthentication", "Ticketing"
                # WARNING: options are CASE SENSITIVE
                $valid = $true
                $acceptedValues = @("None", "Justification", "MultiFactorAuthentication", "Ticketing")
                $_ | ForEach-Object { if (!( $acceptedValues -Ccontains $_)) { $valid = $false } }
                return $valid
            })]
        [System.String[]]
        $ActivationRequirement,
        
        [Parameter()]
        [Bool]
        # Is approval required to activate a role? ($true|$false)
        $ApprovalRequired,
    
        [Parameter()]
        # Array of approvers in the format: @(@{"Id"=<ObjectID>;"Name"="John":"Type"="user|group"}, .... )
        $Approvers,
        
        [Parameter()]
        [System.String]
        # Maximum Eligility Duration
        $MaximumEligibilityDuration = $null,
        
        [Parameter()]
        [Bool]
        # Allow permanent eligibility? ($true|$false)
        $AllowPermanentEligibility,
    
        [Parameter()]
        [System.String]
        # Maximum active assignment duration # Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
        $MaximumActiveAssignmentDuration = $null,
    
        [Parameter()]
        [Bool]
        # Allow permanent active assignement? ($true|$false)
        $AllowPermanentActiveAssignment,
    
        [Parameter()]
        [System.Collections.Hashtable]
        # Admin Notification when eligible role is assigned
        # Format:  @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_EligibleAssignment_Alert,
        
        [Parameter()]
        [System.Collections.Hashtable]
        # End user notification when eligible role is assigned
        # Format:  @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_EligibleAssignment_Assignee,
        
        [Parameter()]
        [System.Collections.Hashtable]
        # Approver notification when eligible role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_EligibleAssignment_Approver,
        
        [Parameter()]
        [System.Collections.Hashtable]
        # Admin Notification when an active role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_ActiveAssignment_Alert,
    
        [Parameter()]
        [System.Collections.Hashtable]
        # End user Notification when an active role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_ActiveAssignment_Assignee,
    
        [Parameter()]
        [System.Collections.Hashtable]
        # Approver Notification when an active role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_ActiveAssignment_Approver,
    
        [Parameter()]
        [System.Collections.Hashtable]
        # Admin Notification when a is activated
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_Activation_Alert,
    
        [Parameter()]
        [System.Collections.Hashtable]
        # End user Notification when a role is activated
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_Activation_Assignee,
    
        [Parameter()]
        [System.Collections.Hashtable]
        # Approvers Notification when a role is activated
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")}
        $Notification_Activation_Approver
      
    )
    try {
        $p = @()
        $PSBoundParameters.Keys | ForEach-Object {
            $p += "$_ =>" + $PSBoundParameters[$_]
        }
        $p = $p -join ', '
       
        log "Function Set-PIMAzureResourcePolicy is starting with parameters: $p" -noEcho

        $script:subscriptionID = $subscriptionID
        $scope = "subscriptions/$script:subscriptionID"
        $script:tenantID=$tenantID

        #at least one approver required if approval is enable
        # todo chech if a parameterset would be better
        if ($ApprovalRequired -eq $true -and $null -eq $Approvers ) { throw "`n /!\ At least one approver is required if approval is enable, please set -Approvers parameter`n`n" }

        $rolename | ForEach-Object {
            $config = get-config $scope $_
            $rules = @()

            if ($PSBoundParameters.Keys.Contains('ActivationDuration')) {
                $rules += Set-ActivationDuration $ActivationDuration
            }

            if ($PSBoundParameters.Keys.Contains('ActivationRequirement')) {
                $rules += Set-ActivationRequirement $ActivationRequirement
            }

            # Approval and approvers
            if ( ($PSBoundParameters.Keys.Contains('ApprovalRequired')) -or ($PSBoundParameters.Keys.Contains('Approvers'))) {
                $rules += Set-Approval $ApprovalRequired $Approvers
            }

            # eligibility assignement
            if ( $PSBoundParameters.ContainsKey('MaximumEligibilityDuration') -or ( $PSBoundParameters.ContainsKey('AllowPermanentEligibility'))) {
                #if values are not set, use the ones from the curent config
                if (!( $PSBoundParameters.ContainsKey('MaximumEligibilityDuration'))) { $MaximumEligibilityDuration = $config.MaximumEligibilityDuration }
                if (!( $PSBoundParameters.ContainsKey('AllowPermanentEligibility'))) { $AllowPermanentEligibility = $config.AllowPermanentEligibleAssignment }
                $rules += Set-EligibilityAssignment $MaximumEligibilityDuration $AllowPermanentEligibility
            }
     
            #active assignement limits
            if ( $PSBoundParameters.ContainsKey('MaximumActiveAssignmentDuration') -or ( $PSBoundParameters.ContainsKey('AllowPermanentActiveAssignment'))) {
                #if values are not set, use the ones from the curent config
                if (!( $PSBoundParameters.ContainsKey('MaximumActiveAssignmentDuration'))) { $MaximumEligibilityDuration = $config.MaximumActiveAssignmentDuration }
                if (!( $PSBoundParameters.ContainsKey('AllowPermanentActiveAssignment'))) { $AllowPermanentEligibility = $config.AllowPermanentActiveAssignment }
                $rules += Set-ActiveAssignment $MaximumActiveAssignmentDuration $AllowPermanentActiveAssignment
            }

            #################
            # Notifications #
            #################

            # Notif Eligibility assignment Alert
            if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Alert')) {
                $rules += Set-Notification_EligibleAssignment_Alert $Notification_EligibleAssignment_Alert
            }

            # Notif elligibility assignee
            if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Assignee')) {
                $rules += Set-Notification_EligibleAssignment_Assignee $Notification_EligibleAssignment_Assignee
            }

            # Notif elligibility approver
            if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Approver')) {
                $rules += Set-Notification_EligibleAssignment_Approver $Notification_EligibleAssignment_Approver
            }

            # Notif Active Assignment Alert
            if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Alert')) {
                $rules += Set-Notification_ActiveAssignment_Alert $Notification_ActiveAssignment_Alert
            }
      
            # Notif Active Assignment Assignee
            if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Assignee')) {
                $rules += Set-Notification_ActiveAssignment_Assignee $Notification_ActiveAssignment_Assignee
            }

            # Notif Active Assignment Approvers
            if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Approver')) {
                $rules += Set-Notification_ActiveAssignment_Approver $Notification_ActiveAssignment_Approver
            }
        
            # Notification Activation alert
            if ($PSBoundParameters.Keys.Contains('Notification_Activation_Alert')) {
                $rules += Set-Notification_Activation_Alert $Notification_Activation_Alert
            }

            # Notification Activation Assignee
            if ($PSBoundParameters.Keys.Contains('Notification_Activation_Assignee')) {
       
                $rules += Set-Notification_Activation_Assignee $Notification_Activation_Assignee
            }

            # Notification Activation Approvers
            if ($PSBoundParameters.Keys.Contains('Notification_Activation_Approver')) {
                $rules += Set-Notification_Activation_Approver $Notification_Activation_Approver
            }

            # Bringing all the rules together and patch the policy
            $allrules = $rules -join ','
            #Write-Verbose "All rules: $allrules"

            #Patching the policy
            if ($PSCmdlet.ShouldProcess($_, "Udpdating policy")) {
                $null=Update-Policy $config.policyID $allrules
            }
            
        }
        log "Success, policy updated"
        return
    }
    catch {
        MyCatch $_
    }
    
}