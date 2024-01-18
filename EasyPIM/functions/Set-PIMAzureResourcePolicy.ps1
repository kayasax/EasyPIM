<# 
      .Synopsis
       Set the setting of the role $rolename at the subscription scope where subscription = $subscription
      .Description
       Get the setting of the role $rolename at the subscription scope where subscription = $subscription
      .Parameter subscriptionID 
       subscription ID
      .Parameter rolename
       Array of the rolename to check
      .Parameter copyfrom
       We will copy the settings from this role to rolename
      .Example
        Get-PIMAzureResourcePolicy -subscriptionID "eedcaa84-3756-4da9-bf87-40068c3dd2a2"  -rolename contributor,webmaster
      .Link
     
      .Notes
     #>
function Set-PIMAzureResourcePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,
        [Parameter(Position = 1, Mandatory = $true)]
        [System.String]
        $subscriptionID,

        [Parameter(Position = 2, Mandatory = $true)]
        [System.String[]]
        $rolename,

        [System.String]
        # Maximum activation duration
        $ActivationDuration = $null,
       
        [Parameter(ParameterSetName = 'Default', HelpMessage = "Accepted values: 'None' or any combination of these options (Case SENSITIVE):  'Justification, 'MultiFactorAuthentication', 'Ticketing'", ValueFromPipeline = $true)]
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
        
        [Parameter(ParameterSetName = 'Default')]
        [Bool]
        # Is approval required to activate a role? ($true|$false)
        $ApprovalRequired,
    
        [Parameter(ParameterSetName = 'Default')]
        # Array of approvers in the format: @(@{"Id"="XXXXXX";"Name"="John":"Type"="user|group"}, .... )
        $Approvers, 
        
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.String]
        # Maximum Eligility Duration
        $MaximumEligibilityDuration = $null,
        
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [Bool]
        # Allow permanent eligibility? ($true|$false)
        $AllowPermanentEligibility,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.String]
        # Maximum active assignment duration # Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
        $MaximumActiveAssignmentDuration = $null, 
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [Bool]
        # Allow permanent active assignement? ($true|$false)
        $AllowPermanentActiveAssignment,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # Admin Notification when eligible role is assigned
        # Format:  @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_EligibleAssignment_Alert, 
        
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # End user notification when eligible role is assigned
        # Format:  @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_EligibleAssignment_Assignee, 
        
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # Approver notification when eligible role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_EligibleAssignment_Approver, 
        
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # Admin Notification when an active role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_ActiveAssignment_Alert,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # End user Notification when an active role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_ActiveAssignment_Assignee,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # Approver Notification when an active role is assigned
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_ActiveAssignment_Approver,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # Admin Notification when a is activated
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_Activation_Alert,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
        [System.Collections.Hashtable]
        # End user Notification when a role is activated
        # Format: @{"isDefaultRecipientEnabled"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
        $Notification_Activation_Assignee,
    
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Default')]
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
            $null=Update-Policy $config.policyID $allrules
        }
        log "Success, policy updated"
        return
    }
    catch {
        MyCatch $_
    }
    
}