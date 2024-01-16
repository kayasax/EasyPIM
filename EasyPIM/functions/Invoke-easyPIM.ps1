function Invoke-EasyPIM{
    <# 
.Synopsis
EASYPIM
Powershell function to manage PIM Azure Resource Role settings with simplicity in mind

Easily manage settings at the subscription level : enter a tenant ID, a subscription ID, a role name  
then the options you want to set for example require justification on activation

* Support editing multi roles at once
* Export role settings to csv
* Import from csv
* Copy settings from another role
* Backup (export all roles settings)

Sample usage
EasyPIM.PS1 -TenantID <tenantID> -SubscriptionId <subscriptionID> -rolename "webmaster" -ActivationRequirement "Justification","MultiFactorAuthentication"

.Description
 
EasyPIM will manage the MS Graph APIs calls to implement the settings you want. You can set these settings individualy, copying them from another role or by importing a csv file.
EasyPIM will create the rules and use a PATCH request to update  the settings.
 
.Example
       *  show curent config :
       wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -show
    
       *  Set Activation duration to 14h
       wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -ActivationDuration "PT14H"
    
       *  Require approval on activation and define approvers
        wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -ApprovalRequired $true -Approvers @( @{"id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"name"="Bob";"type"="User"} , @{"id"="cf0a2f3e-1223-49d4-b10b-01f2538dd5d7";"name"="TestDL";"type"="Group"} )
    
       *  Disable approval
        wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -ApprovalRequired $false 


        .Link
    https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-rest-api 
    https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview
    Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
.Notes
    Homepage: https://github.com/kayasax/easyPIM
    Author: MICHEL, Loic <loic.michel@yespapa.eu>
    Changelog:
    Todo: 
    * configure paramet sets
    * allow other scopes
#>

[CmdletBinding( DefaultParameterSetName = 'Default')] #make script react as cmdlet (-verbose etc..)
param(
    [Parameter(ParameterSetName = 'Default', Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Show', Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Backup', Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Import', Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Export', Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Copy', Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    # Entra ID TenantID
    $TenantID,

    [Parameter(ParameterSetName = 'Default', Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Show', Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Backup', Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Import', Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Export', Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Copy', Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    # Subscription ID
    $SubscriptionId,

    [Parameter(ParameterSetName = 'Default', Position = 2, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Show', Position = 2, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Export', Position = 2, Mandatory = $true, ValueFromPipeline = $true)]
    [Parameter(ParameterSetName = 'Copy', Position = 2, Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String[]]
    # name of roles to update/export ex -rolename "webmaster","contributor"
    $rolename,

    [Parameter(ParameterSetName = 'Show')]
    [Switch]
    # show current config only, no change made
    $show, 

    [Parameter(ParameterSetName = 'Export', Mandatory = $true)]
    [Switch]
    # export role config to csv
    $export, 

    [Parameter(ParameterSetName = 'Export')]
    [String]
    # save export to this file
    $exportFilename = $null,

    [Parameter(ParameterSetName = 'Import', Mandatory = $true, ValueFromPipeline = $true)]
    [String]
    # import settings from this csv file
    $import = $null,

    [Parameter(ParameterSetName = 'Copy', Mandatory = $true)]
    [String]
    # copy settings from this role name 
    $copyFrom = "",
    
    [Parameter(Position = 0, ParameterSetName = 'Backup')]
    [Switch]
    # backup all roles to csv 
    $backup,

    [Parameter(ParameterSetName = 'Default')]
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
            $valid
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
    $Notification_EligibleAssignment_Approvers, 
    
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
    $Notification_ActiveAssignment_Approvers,

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
    $Notification_Activation_Approvers
)


#***************************************
#* CONFIGURATION
#***************************************

# LOG TO FILE ( if enable by default it will create a LOGS subfolder in the script folder, and create a logfile with the name of the script )
$logToFile = $true

# TEAMS NOTIDICATION
# set to $true if you want to send fatal error on a Teams channel using Webhook see doc to setup
$TeamsNotif = $true
#The description will be used as the notification subject
$description = "PIM Azure role setting" 

#***************************************
#* PRIVATE VARIABLES DON'T TOUCH !!
#***************************************

#from now every error will be treated as exception and terminate the script


    
try {
    # ******************************************
    # * Script is starting
    # ******************************************
    
    $p = @()
    $PSBoundParameters.Keys | % {
        $p += "$_ =>" + $PSBoundParameters[$_]
    }
    $p = $p -join ', '
    log "
    ****************************************" -noEcho
    log "Script is starting with parameters: $p" -noEcho

    #at least one approver required if approval is enable
    # todo chech if a parameterset would be better
    if ($ApprovalRequired -eq $true -and $Approvers -eq $null) { throw "`n /!\ At least one approver is required if approval is enable, please set -Approvers parameter`n`n" }
    
    $scope = "subscriptions/$subscriptionID"
    $ARMhost = "https://management.azure.com"
    $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"
    
    # Log in first with Connect-AzAccount if not using Cloud Shell
    Write-Verbose ">> Connecting to Azure with tenantID $tenantID"
    if ( (get-azcontext) -eq $null) { Connect-AzAccount -Tenant $tenantID }

    # Get access Token
    Write-Verbose ">> Getting access token"
    $token = Get-AzAccessToken
    #Write-Verbose ">> token=$($token.Token)"
    
    # setting the authentication headers for MSGraph calls
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $token.Token
    }

    # importing from a csv
    if ($import) {
        Import-Settings $import
        Log "Success, exiting."
        return  
    }

    # copy from another role
    elseif ("" -ne $copyFrom) {
        Log "Copying settings from $copyFrom"
        $config2 = get-config $scope $copyFrom $true
        
        $rolename | % {
            $config = get-config $scope $_
            [string]$policyID = $config.policyID
            $policyID = $policyID.Trim()
            Update-Policy $policyID $config2 
        }
        exit
    }

    # export all roles
    if ($backup) {
        $exports = @()
        $policies = Get-AllPolicies
        
        $policies | % {
            log "exporting $_ role settings"
            write-verbose  $_
            $exports += get-config $scope $_.Trim()
        }
        $date = get-date -Format FileDateTime
        if (!($exportFilename)) { $exportFilename = ".\EXPORTS\BACKUP_$date.csv" }
        log "exporting to $exportFilename"
        $exportPath = Split-Path $exportFilename -Parent
        #create export folder if no exist
        if ( !(test-path  $exportFilename) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }
        
        $exports | select * | ConvertTo-Csv | out-file $exportFilename
        exit
    }

    # Array to contain the settings of each selected roles 
    $exports = @()

    # run the flow for each role name.
    $rolename | ForEach-Object {
        
        #get curent config
        $config = get-config $scope $_

        if ($show) {
            #show curent config and quit
            return $config # $response 
        }

        if ( $export ) {
            $exports += $config     
        }
        
        # Build our rules to patch the policy based on parameter used
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
        if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Approvers')) {
            $rules += Set-Notification_EligibleAssignment_Approvers $Notification_EligibleAssignment_Approvers
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
        if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Approvers')) {
            $rules += Set-Notification_ActiveAssignment_Approvers $Notification_ActiveAssignment_Approvers
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
        if ($PSBoundParameters.Keys.Contains('Notification_Activation_Approvers')) {
            $rules += Set-Notification_Activation_Approvers $Notification_Activation_Approvers
        }

        # Bringing all the rules together and patch the policy
        $allrules = $rules -join ','
        #Write-Verbose "All rules: $allrules"

        #Patching the policy
        Update-Policy $config.policyID $allrules
    }
    
    # finalize export
    if ($export) {
        $date = get-date -Format FileDateTime
        if (!($exportFilename)) { $exportFilename = ".\EXPORTS\$date.csv" }
        log "exporting to $exportFilename"
        $exportPath = Split-Path $exportFilename -Parent
        #create export folder if no exist
        if ( !(test-path  $exportFilename) ) {
            $null = New-Item -ItemType Directory -Path $exportPath -Force
        }
        $exports | select * | ConvertTo-Csv | out-file $exportFilename
    }
}

catch {
    $_ # echo the exception
    $err = $($_.exception.message | out-string) 
    $errorRecord = $Error[0] 
    $details = $errorRecord.errordetails # |fl -force
    $position = $errorRecord.InvocationInfo.positionMessage
    $Exception = $ErrorRecord.Exception
    
    if ($TeamsNotif) { send-teamsnotif "$err" "$details<BR/> TIPS: try to check the scope and the role name" "$position" }
    Log "An exception occured: $err `nDetails: $details `nPosition: $position"
    Log "Error, script did not terminate normaly"
    break
}

log "Success! Script ended normaly"
}