<#
      .Synopsis
       Set the setting of the role $rolename
      .Description
       Set the setting of the role $rolename
      .Example
        PS> Set-PIMEntraRolePolicy -tenantID $tenantID -rolename webmaster -ActivationDuration "PT8H"

        Limit the maximum PIM activation duration to 8h
      .EXAMPLE
        PS> Set-PIMEntraRolePolicy -TenantID $tenantID -rolename "contributor" -Approvers  @(@{"Id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"Name"="John";"Type"="user"}) -ApprovalRequired $true

        Require activation approval and set John as an approver

      .Link

      .Notes
        Author: Loïc MICHEL
        Homepage: https://github.com/kayasax/EasyPIM
     #>
function Set-PIMEntraRolePolicy {
    [CmdletBinding(DefaultParameterSetName='Default',SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID,

        [Parameter(Position = 1, Mandatory = $true)]
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
                $script:valid = $true
                $acceptedValues = @("None", "Justification", "MultiFactorAuthentication", "Ticketing")
                $_ | ForEach-Object { if (!( $acceptedValues -Ccontains $_)) { $script:valid = $false } }
                return $script:valid
            })]
        [System.String[]]
        # Activation requirement
        $ActivationRequirement,

        [Parameter(HelpMessage = "Accepted values: 'None' or any combination of these options (Case SENSITIVE):  'Justification, 'MultiFactorAuthentication'")]
        [ValidateScript({
                # accepted values: "None","Justification", "MultiFactorAuthentication"
                # WARNING: options are CASE SENSITIVE
                $script:valid = $true
                $acceptedValues = @("None", "Justification", "MultiFactorAuthentication")
                $_ | ForEach-Object { if (!( $acceptedValues -Ccontains $_)) { $script:valid = $false } }
                return $script:valid
            })]
        [System.String[]]
        # Active assignment requirement
        $ActiveAssignmentRequirement,

        [Parameter()]
        [Bool]
        # Is authentication context required? ($true|$false)
        $AuthenticationContext_Enabled,

        [Parameter()]
        [String]
        # Authentication context value? (ex c1)
        $AuthenticationContext_Value,

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

        write-verbose "Function Set-PIMEntraRolePolicy is starting with parameters: $p"

        $script:tenantID=$tenantID

        #at least one approver required if approval is enable
        # todo chech if a parameterset would be better
        if ($ApprovalRequired -eq $true -and $null -eq $Approvers ) { throw "`n /!\ At least one approver is required if approval is enable, please set -Approvers parameter`n`n" }

        $rolename | ForEach-Object {
            $script:config = get-EntraRoleconfig $_
            $rules = @()

            if ($PSBoundParameters.Keys.Contains('ActivationDuration')) {
                $rules += Set-ActivationDuration $ActivationDuration -EntraRole
            }

            if ($PSBoundParameters.Keys.Contains('ActivationRequirement')) {
                $ar = $ActivationRequirement
                # If Authentication Context is being enabled in the same patch, optionally remove MFA to avoid conflict
                if ($PSBoundParameters.Keys.Contains('AuthenticationContext_Enabled') -and ($AuthenticationContext_Enabled -eq $true)) {
                    $autoResolve = if ($null -ne $global:EasyPIM_AutoResolveMfaAcrConflict) { [bool]$global:EasyPIM_AutoResolveMfaAcrConflict } else { $true }
                    if ($autoResolve) {
                        if ($ar -and ($ar -contains 'MultiFactorAuthentication')) {
                            Write-Verbose "Removing 'MultiFactorAuthentication' from Enablement_EndUser_Assignment because Authentication Context is enabled (avoids MfaAndAcrsConflict)"
                            $ar = @($ar | Where-Object { $_ -ne 'MultiFactorAuthentication' })
                        }
                    } else {
                        Write-Verbose "Leaving 'MultiFactorAuthentication' as-is per EasyPIM_AutoResolveMfaAcrConflict = false (Graph may reject)"
                    }
                }
                $rules += Set-ActivationRequirement $ar -EntraRole
            }

            if ($PSBoundParameters.Keys.Contains('ActiveAssignmentRequirement')) {
                $rules += Set-ActiveAssignmentRequirement $ActiveAssignmentRequirement -EntraRole
            }
            if ($PSBoundParameters.Keys.Contains('AuthenticationContext_Enabled')) {
                if (!($PSBoundParameters.Keys.Contains('AuthenticationContext_Value'))) {
                    $AuthenticationContext_Value = $null
                }
                $rules += Set-AuthenticationContext $AuthenticationContext_Enabled $AuthenticationContext_Value -entraRole
                # If caller didn't pass ActivationRequirement, but current config enforces MFA,
                # optionally remove MFA to prevent MfaAndAcrsConflict when enabling Authentication Context.
                if ($AuthenticationContext_Enabled -eq $true -and -not $PSBoundParameters.Keys.Contains('ActivationRequirement')) {
                    $currentEnablement = @()
                    if ($script:config.EnablementRules) { $currentEnablement = ($script:config.EnablementRules -split ',') }
                    $autoResolve = if ($null -ne $global:EasyPIM_AutoResolveMfaAcrConflict) { [bool]$global:EasyPIM_AutoResolveMfaAcrConflict } else { $true }
                    if ($autoResolve) {
                        if ($currentEnablement -contains 'MultiFactorAuthentication') {
                            Write-Verbose "Current policy has 'MultiFactorAuthentication' enabled; adding Enablement_EndUser_Assignment without MFA to avoid conflict with Authentication Context."
                            $filtered = @($currentEnablement | Where-Object { $_ -ne 'MultiFactorAuthentication' })
                            $rules += Set-ActivationRequirement $filtered -EntraRole
                        }
                    } else {
                        Write-Verbose "EasyPIM_AutoResolveMfaAcrConflict = false; not adding a filtered Enablement rule."
                    }
                }
            }

            # Approval and approvers
            if ( ($PSBoundParameters.Keys.Contains('ApprovalRequired')) -or ($PSBoundParameters.Keys.Contains('Approvers'))) {
                $rules += Set-Approval $ApprovalRequired $Approvers -EntraRole
            }

            # eligibility assignement
            if ( $PSBoundParameters.ContainsKey('MaximumEligibilityDuration') -or ( $PSBoundParameters.ContainsKey('AllowPermanentEligibility'))) {
                #if values are not set, use the ones from the curent config
                write-verbose "Maximum Eligibiliy duration from curent config: $($script:config.MaximumEligibleAssignmentDuration)"
                if (!( $PSBoundParameters.ContainsKey('MaximumEligibilityDuration'))) { $MaximumEligibilityDuration = $script:config.MaximumEligibleAssignmentDuration }
                if (!( $PSBoundParameters.ContainsKey('AllowPermanentEligibility'))) { $AllowPermanentEligibility = $script:config.AllowPermanentEligibleAssignment }
                if ( ($false -eq $AllowPermanentEligibility) -and ( ($MaximumEligibilityDuration -eq "") -or ($null -eq $MaximumEligibilityDuration) )){
                    throw "ERROR: you requested the assignement to expire but the maximum duration is not defined, please use the MaximumEligibilityDuration parameter"
                }
                $rules += Set-EligibilityAssignment $MaximumEligibilityDuration $AllowPermanentEligibility -entraRole
            }

            #active assignement limits
            if ( $PSBoundParameters.ContainsKey('MaximumActiveAssignmentDuration') -or ( $PSBoundParameters.ContainsKey('AllowPermanentActiveAssignment'))) {
                #if values are not set, use the ones from the curent config
                write-verbose "Maximum Active duration from curent config: $($script:config.MaximumActiveAssignmentDuration)"
                if (!( $PSBoundParameters.ContainsKey('MaximumActiveAssignmentDuration'))) { $MaximumActiveAssignmentDuration = $script:config.MaximumActiveAssignmentDuration }
                if (!( $PSBoundParameters.ContainsKey('AllowPermanentActiveAssignment'))) { $AllowPermanentActiveAssignment = $script:config.AllowPermanentActiveAssignment }
                if ( ($false -eq $AllowPermanentActiveAssignment) -and ( ($MaximumActiveAssignmentDuration -eq "") -or ($null -eq $MaximumActiveAssignmentDuration) )){
                    throw "ERROR: you requested the assignement to expire but the maximum duration is not defined, please use the MaximumActiveAssignmentDuration parameter"
                }
                $rules += Set-ActiveAssignment $MaximumActiveAssignmentDuration $AllowPermanentActiveAssignment -entraRole
            }

            #################
            # Notifications #
            #################

            # Notif Eligibility assignment Alert
            if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Alert')) {
                $rules += Set-Notification_EligibleAssignment_Alert $Notification_EligibleAssignment_Alert -entraRole
            }

            # Notif elligibility assignee
            if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Assignee')) {
                $rules += Set-Notification_EligibleAssignment_Assignee $Notification_EligibleAssignment_Assignee -entraRole
            }

            # Notif elligibility approver
            if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Approver')) {
                $rules += Set-Notification_EligibleAssignment_Approver $Notification_EligibleAssignment_Approver -entraRole
            }

            # Notif Active Assignment Alert
            if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Alert')) {
                $rules += Set-Notification_ActiveAssignment_Alert $Notification_ActiveAssignment_Alert -entraRole
            }

            # Notif Active Assignment Assignee
            if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Assignee')) {
                $rules += Set-Notification_ActiveAssignment_Assignee $Notification_ActiveAssignment_Assignee -entraRole
            }

            # Notif Active Assignment Approvers
            if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Approver')) {
                $rules += Set-Notification_ActiveAssignment_Approver $Notification_ActiveAssignment_Approver -entraRole
             }

            # Notification Activation alert
            if ($PSBoundParameters.Keys.Contains('Notification_Activation_Alert')) {
                $rules += Set-Notification_Activation_Alert $Notification_Activation_Alert -entraRole
            }

            # Notification Activation Assignee
            if ($PSBoundParameters.Keys.Contains('Notification_Activation_Assignee')) {

                $rules += Set-Notification_Activation_Assignee $Notification_Activation_Assignee -entraRole
            }

            # Notification Activation Approvers
            if ($PSBoundParameters.Keys.Contains('Notification_Activation_Approver')) {
                $rules += Set-Notification_Activation_Approver $Notification_Activation_Approver -entraRole
            }

            # Bringing all the rules together and patch the policy
            $allrules = $rules -join ','
            #Write-Verbose "All rules: $allrules"

            #Patching the policy
            if ($PSCmdlet.ShouldProcess($_, "Udpdating policy")) {
               $null = Update-EntraRolePolicy $script:config.policyID $allrules
            }

        }
        log "Success, policy updated"
        return
    }
    catch {
        MyCatch $_
    }

}
