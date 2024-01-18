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


#***************************************
#* CONFIGURATION
#***************************************

# LOG TO FILE ( if enable by default it will create a LOGS subfolder in the script folder, and create a logfile with the name of the script )
$logToFile = $true

# TEAMS NOTIDICATION
# set to $true if you want to send fatal error on a Teams channel using Webhook see doc to setup
$TeamsNotif = $true
# your Teams Inbound WebHook URL
$teamsWebhookURL = "https://microsoft.webhook.office.com/webhookb2/0b9bf9c2-fc4b-42b2-aa56-c58c805068af@72f988bf-86f1-41af-91ab-2d7cd011db47/IncomingWebhook/40db225a69854e49b617eb3427bcded8/8dd39776-145b-4f26-8ac4-41c5415307c7"
#The description will be used as the notification subject
$description = "PIM Azure role setting" 

#***************************************
#* PRIVATE VARIABLES DON'T TOUCH !!
#***************************************
$_scriptFullName = $MyInvocation.myCommand.definition
$_scriptName = Split-Path -Leaf $_scriptFullName
$_scriptPath = split-path -Parent   $_scriptFullName
$HostFQDN = $env:computername + "." + $env:USERDNSDOMAIN

# ERROR HANDLING
$ErrorActionPreference = "STOP" # make all errors terminating ones so they can be catched

#from now every error will be treated as exception and terminate the script

    
<# 
      .Synopsis
       Log message to file and display it on screen with basic colour hilighting.
       The function include a log rotate feature.
      .Description
       Write $msg to screen and file with additional inforamtions : date and time, 
       name of the script from where the function was called, line number and user who ran the script.
       If logfile path isn't specified it will default to C:\UPF\LOGS\<scriptname.ps1.log>
       You can use $Maxsize and $MaxFile to specified the size and number of logfiles to keep (default is 3MB, and 3files)
       Use the switch $noEcho if you dont want the message be displayed on screen
      .Parameter msg 
       The message to log
      .Parameter logfile
       Name of the logfile to use (default = <scriptname>.ps1.log)
      .Parameter logdir
       Path to the logfile's directory (defaut = <scriptpath>\LOGS)
       .Parameter noEcho 
       Don't print message on screen
      .Parameter maxSize
       Maximum size (in bytes) before logfile is rotate (default is 3MB)
      .Parameter maxFile
       Number of logfile history to keep (default is 3)
      .Example
        log "A message to display on screen and file"
      .Example
        log "this message will not appear on screen" -noEcho
      .Link
     
      .Notes
      	Changelog :
         * 27/08/2017 version initiale	
         * 21/09/2017 correction of rotating step
      	Todo : 
     #>
function log {
    [CmdletBinding()]
    param(
        [string]$msg,
        $logfile = $null,
        $logdir = $(join-path -path $script:_scriptPath -childpath "LOGS"), # Path to logfile
        [switch]$noEcho, # if set dont display output to screen, only to logfile
        $MaxSize = 3145728, # 3MB
        #$MaxSize = 1,
        $Maxfile = 3 # how many files to keep
    )

    #do nothing if logging is disabled
    if ($true -eq $logToFile ) {
     
        # When no logfile is specified we append .log to the scriptname 
        if ( $logfile -eq $null ) { 
            $logfile = $(Split-Path -Leaf $MyInvocation.ScriptName) + ".log"
        }
       
        # Create folder if needed
        if ( !(test-path  $logdir) ) {
            $null = New-Item -ItemType Directory -Path $logdir  -Force
        }
         
        # Ensure logfile will be save in logdir
        if ( $logfile -notmatch [regex]::escape($logdir)) {
            $logfile = "$logdir\$logfile"
        }
         
        # Create file
        if ( !(Test-Path $logfile) ) {
            write-verbose "$logfile not found, creating it"
            $null = New-Item -ItemType file $logfile -Force  
        }
        else {
            # file exists, do size exceeds limit ?
            if ( (get-childitem $logfile | select -expand length) -gt $Maxsize) {
                echo "$(Get-Date -Format yyy-MM-dd-HHmm) - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : Log size exceed $MaxSize, creating a new file." >> $logfile 
                 
                # rename current logfile
                $LogFileName = $($($LogFile -split "\\")[-1])
                $basename = ls $LogFile | select -expand basename
                $dirname = ls $LogFile | select -expand directoryname
     
                Write-Verbose "Rename-Item $LogFile ""$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"""
                Rename-Item $LogFile "$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"
     
                # keep $Maxfile  logfiles and delete the older ones
                $filesToDelete = ls  "$dirname\$basename*.log" | sort LastWriteTime -desc | select -Skip $Maxfile 
                $filesToDelete | remove-item  -force
            }
        }
     
        echo "$(Get-Date -Format yyy-MM-dd-HHmm) - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : $msg" >> $logfile
    }# end logging to file

    # Display $msg if $noEcho is not set
    if ( $noEcho -eq $false) {
        #colour it up...
        if ( $msg -match "Erreur|error") {
            write-host $msg -ForegroundColor red
        }
        elseif ($msg -match "avertissement|attention|warning") {
            write-host $msg -ForegroundColor yellow
        }
        elseif ($msg -match "info|information") {
            write-host $msg -ForegroundColor cyan
        }    
        elseif ($msg -match "succès|succes|success|OK") {
            write-host $msg -ForegroundColor green
        }
        else {
            write-host $msg 
        }
    }
} #end function log
function send-teamsnotif {
    [CmdletBinding()] #make script react as cmdlet (-verbose etc..)
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $message,
        [string] $details,
        [string] $myStackTrace = $null
    )

    $JSONBody = @{
        "@type"    = "MessageCard"
        "@context" = "<http://schema.org/extensions>"
        "title"    = "Alert for $description @ $env:computername  "
        "text"     = "An exception occured:"
        "sections" = @(
            @{
                "activityTitle" = "Message : $message"
            },
            @{
                "activityTitle" = "Details : $details"
            },
            @{
                "activityTitle" = " Script path "
                "activityText"  = "$_scriptFullName"
            },
            
            @{
                "activityTitle" = "myStackTrace"
                "activityText"  = "$myStackTrace"
            }
        )
    }

    $TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100
        
    $parameters = @{
        "URI"         = $teamsWebhookURL
        "Method"      = 'POST'
        "Body"        = $TeamMessageBody
        "ContentType" = 'application/json'
    }
    $null = Invoke-RestMethod @parameters
}#end function senfd-teamsnotif

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
      
    }
    catch {
        log "An Error occured while trying to get the setting of role $rolename"
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
    $_Notification_Activation_Approver = $response.properties.rules | ? { $_.id -eq "Notification_Approver_EndUser_Assignment" } 


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
        Notification_Activation_Approver_isDefaultRecipientEnabled  = $($_Notification_Activation_Approver.isDefaultRecipientsEnabled)
        Notification_Activation_Approver_NotificationLevel          = $($_Notification_Activation_Approver.NotificationLevel)
        Notification_Activation_Approver_Recipients                 = $($_Notification_Activation_Approver.NotificationRecipients -join ',')
    }
    return $config

} #end function get-config

function Set-ActivationDuration ($ActivationDuration) {
    # Set Maximum activation duration
    if ( ($null -ne $ActivationDuration) -and ("" -ne $ActivationDuration) ) {
        Write-Verbose "Editing Activation duration : $ActivationDuration"
        $properties = @{
            "isExpirationRequired" = "true";
            "maximumDuration"      = "$ActivationDuration";
            "id"                   = "Expiration_EndUser_Assignment";
            "ruleType"             = "RoleManagementPolicyExpirationRule";
            "target"               = @{
                "caller"     = "EndUser";
                "operations" = @("All")
            };
            "level"                = "Assignment"
        }       
        $rule = $properties | ConvertTo-Json
        #update rules if required
        return $rule
    }
}# end function set-ActivationDuration

function Set-ActivationRequirement($ActivationRequirement) {
    write-verbose "Set-ActivationRequirement : $($ActivationRequirement.length)"
    if (($ActivationRequirement -eq "None") -or ($ActivationRequirement[0].length -eq 0 )) {
        #if none or a null array
        write-verbose "requirement is nul"
        $enabledRules = "[],"
    }
    else {
        write-verbose "requirement is NOT nul"
        $formatedRules = '['
            
        $ActivationRequirement | % {
            $formatedRules += '"'
            $formatedRules += "$_"
            $formatedRules += '",'
        }
        #remove last comma
        $formatedRules = $formatedRules -replace “.$”

        $formatedRules += "],"
        $enabledRules = $formatedRules
        #Write-Verbose "************* $enabledRules "
    }
            
    $properties = '{
                "enabledRules": '+ $enabledRules + '
                "id": "Enablement_EndUser_Assignment",
                "ruleType": "RoleManagementPolicyEnablementRule",
                "target": {
                    "caller": "EndUser",
                    "operations": [
                        "All"
                    ],
                    "level": "Assignment",
                    "targetObjects": [],
                    "inheritableSettings": [],
                    "enforcedSettings": []
                }
            }'

    return $properties
} #end function set-ActivationRequirement

function Set-Approval ($ApprovalRequired, $Approvers) {
    Write-Verbose "Set-Approval"       
    if ($null -eq $Approvers) { $Approvers = $config.Approvers }
    if ($ApprovalRequired -eq $false) { $req = "false" }else { $req = "true" }
        
    $rule = '
        {
        "setting": {'
    if ($null -ne $ApprovalRequired) {
        $rule += '"isApprovalRequired": ' + $req + ','
    }
    $rule += '
        "isApprovalRequiredForExtension": false,
        "isRequestorJustificationRequired": true,
        "approvalMode": "SingleStage",
        "approvalStages": [
            {
            "approvalStageTimeOutInDays": 1,
            "isApproverJustificationRequired": true,
            "escalationTimeInMinutes": 0,
        '

    if ($null -ne $Approvers) {
        #at least one approver required if approval is enable
        $rule += '
            "primaryApprovers": [
            '
        $cpt = 0    
        $Approvers | ForEach-Object {
            #write-host $_
            $id = $_.Id
            $name = $_.Name
            $type = $_.Type

            if ($cpt -gt 0) {
                $rule += ","
            }
            $rule += '
            {
                "id": "'+ $id + '",
                "description": "'+ $name + '",
                "isBackup": false,
                "userType": "'+ $type + '"
            }
            '
            $cpt++
        }

        $rule += '
            ],'
    }

    $rule += ' 
        "isEscalationEnabled": false,
            "escalationApprovers": null
                    }]
                 },
        "id": "Approval_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyApprovalRule",
        "target": {
            "caller": "EndUser",
            "operations": [
                "All"
            ],
            "level": "Assignment",
            "targetObjects": null,
            "inheritableSettings": null,
            "enforcedSettings": null
        
        }}'
    return $rule
}#end function Set-Approval

# we need to parse the approvers list differently when importing from the csv
function Set-ApprovalFromCSV ($ApprovalRequired, $Approvers) {
    write-verbose "Set-ApprovalFromCSV"
    if ($null -eq $Approvers) { $Approvers = $config.Approvers }
    if ($ApprovalRequired -eq $false) { $req = "false" }else { $req = "true" }
        
    $rule = '
        {
        "setting": {'
    if ($null -ne $ApprovalRequired) {
        $rule += '"isApprovalRequired":' + $req + ','
    }
       
    $rule += '
        "isApprovalRequiredForExtension": false,
        "isRequestorJustificationRequired": true,
        "approvalMode": "SingleStage",
        "approvalStages": [
            {
            "approvalStageTimeOutInDays": 1,
            "isApproverJustificationRequired": true,
            "escalationTimeInMinutes": 0,
        '

    if ($null -ne $Approvers) {
        #at least one approver required if approval is enable

        $Approvers = $Approvers -replace "@"
        $Approvers = $Approvers -replace ";", ","
        $Approvers = $Approvers -replace "=", ":"

        $rule += '
            "primaryApprovers": [
            '+ $Approvers
    }

    $rule += '
            ],'
        

    $rule += ' 
        "isEscalationEnabled": false,
            "escalationApprovers": null
                    }]
                 },
        "id": "Approval_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyApprovalRule",
        "target": {
            "caller": "EndUser",
            "operations": [
                "All"
            ],
            "level": "Assignment",
            "targetObjects": null,
            "inheritableSettings": null,
            "enforcedSettings": null
        
        }}'
    return $rule
}#end function Set-ApprovalFromCSV

function Set-EligibilityAssignment($MaximumEligibilityDuration, $AllowPermanentEligibility) {
    write-verbose "Set-EligibilityAssignment: $MaximumEligibilityDuration $AllowPermanentEligibility"
    $max = $MaximumEligibilityDuration
     
    if ( ($true -eq $AllowPermanentEligibility) -or ("true" -eq $AllowPermanentEligibility) -and ("false" -ne $AllowPermanentEligibility)) {
        $expire = "false"
        write-verbose "1 setting expire to : $expire"
    }
    else {
            
        $expire = "true"
        write-verbose "2 setting expire to : $expire"
    }
      
    $rule = '
        {
        "isExpirationRequired": '+ $expire + ',
        "maximumDuration": "'+ $max + '",
        "id": "Expiration_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
          "caller": "Admin",
          "operations": [
            "All"
          ],
          "level": "Eligibility",
          "targetObjects": null,
          "inheritableSettings": null,
          "enforcedSettings": null
        }
    }
    '
    # update rule only if a change was requested
    return $rule
}# end function Set-EligibilityAssignment

function Set-EligibilityAssignmentFromCSV($MaximumEligibilityDuration, $AllowPermanentEligibility) {
    write-verbose "Set-EligibilityAssignmentFromCSV: $MaximumEligibilityDuration $AllowPermanentEligibility"
    $max = $MaximumEligibilityDuration
     
    if ( "true" -eq $AllowPermanentEligibility) {
        $expire = "false"
        write-verbose "1 setting expire to : $expire"
    }
    else {
            
        $expire = "true"
        write-verbose "2 setting expire to : $expire"
    }
      
    $rule = '
        {
        "isExpirationRequired": '+ $expire + ',
        "maximumDuration": "'+ $max + '",
        "id": "Expiration_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
          "caller": "Admin",
          "operations": [
            "All"
          ],
          "level": "Eligibility",
          "targetObjects": null,
          "inheritableSettings": null,
          "enforcedSettings": null
        }
    }
    '
    # update rule only if a change was requested
    return $rule
}# end function Set-EligibilityAssignmentFromCSV
   
function Set-ActiveAssignment($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment) {
    write-verbose "Set-ActiveAssignment($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment)"
    if ( $true -eq 'AllowPermanentActiveAssignment') {
        $expire2 = "false"
    }
    else {
        $expire2 = "true"
    }
            
    $rule = '
        {
        "isExpirationRequired": '+ $expire2 + ',
        "maximumDuration": "'+ $MaximumActiveAssignmentDuration + '",
        "id": "Expiration_Admin_Assignment",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
    '
    return $rule
        
} #end function set-activeAssignment

function Set-ActiveAssignmentFromCSV($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment) {
    write-verbose "Set-ActiveAssignmentFromCSV($MaximumActiveAssignmentDuration, $AllowPermanentActiveAssignment)"
    if ( "true" -eq $AllowPermanentActiveAssignment) {
        $expire2 = "false"
    }
    else {
        $expire2 = "true"
    }
            
    $rule = '
        {
        "isExpirationRequired": '+ $expire2 + ',
        "maximumDuration": "'+ $MaximumActiveAssignmentDuration + '",
        "id": "Expiration_Admin_Assignment",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
    '
    return $rule
        
} #end function set-activeAssignmentFromCSV
function Set-Notification_EligibleAssignment_Alert($Notification_EligibleAssignment_Alert) {
    write-verbose "Set-Notification_EligibleAssignment_Alert($Notification_EligibleAssignment_Alert)"

    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Alert.Recipients | % {
        $rule += '"' + $_ + '",'
    }
    $rule = $rule -replace ".$"
    $rule += '
        ],
        "id": "Notification_Admin_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
    '
    write-verbose "end function notif elligible alert"
    return $rule
}# end function set-Notification_EligibleAssignment_Alert

function Set-Notification_EligibleAssignment_Assignee($Notification_EligibleAssignment_Assignee) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Requestor",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Assignee.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Assignee.Recipients | % {
        $rule += '"' + $_ + '",'
    }
        
    $rule += '
        ],
        "id": "Notification_Requestor_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }'

    return $rule
}# end function Set-Notification_EligibleAssignment_Assignee

function Set-Notification_EligibleAssignment_Approver($Notification_EligibleAssignment_Approver) {
    #write-verbose "function Set-Notification_EligibleAssignment_Approver"
        
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Approver.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_EligibleAssignment_Approver.recipients | % {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Approver_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }'
    return $rule
}# end function Set-Notification_EligibleAssignment_Approver

function Set-Notification_ActiveAssignment_Alert($Notification_ActiveAssignment_Alert) {
    $rule = '
    {
    "notificationType": "Email",
    "recipientType": "Admin",
    "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Alert.isDefaultRecipientEnabled.ToLower() + ',
    "notificationLevel": "'+ $Notification_ActiveAssignment_Alert.notificationLevel + '",
    "notificationRecipients": [
    '
    $Notification_ActiveAssignment_Alert.Recipients | % {
        $rule += '"' + $_ + '",'
    }
    
    $rule += '
    ],
    "id": "Notification_Admin_Admin_Assignment",
    "ruleType": "RoleManagementPolicyNotificationRule",
    "target": {
    "caller": "Admin",
    "operations": [
        "All"
    ],
    "level": "Eligibility",
    "targetObjects": null,
    "inheritableSettings": null,
    "enforcedSettings": null
    }
    }
    '
    return $rule
} #end function Set-Notification_ActiveAssignment_Alert

function Set-Notification_ActiveAssignment_Assignee($Notification_ActiveAssignment_Assignee) {
    $rule = '
                {
                "notificationType": "Email",
                "recipientType": "Requestor",
                "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Assignee.isDefaultRecipientEnabled.ToLower() + ',
                "notificationLevel": "'+ $Notification_ActiveAssignment_Assignee.notificationLevel + '",
                "notificationRecipients": [
                '
    $Notification_ActiveAssignment_Assignee.Recipients | % {
        $rule += '"' + $_ + '",'
    }

    $rule += '
                ],
                "id": "Notification_Requestor_Admin_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "target": {
                "caller": "Admin",
                "operations": [
                    "All"
                ],
                "level": "Eligibility",
                "targetObjects": null,
                "inheritableSettings": null,
                "enforcedSettings": null
                }
                }
                '
    return $rule
} #end function Set-Notification_ActiveAssignment_Assignee

function  Set-Notification_ActiveAssignment_Approver($Notification_ActiveAssignment_Approver) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Approver.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_ActiveAssignment_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_ActiveAssignment_Approver.Recipients | % {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Approver_Admin_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
    return $rule
}

function Set-Notification_Activation_Alert($Notification_Activation_Alert) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Alert.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_Activation_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
    $Notification_Activation_Alert.Recipients | % {
        $rule += '"' + $_ + '",'
    }

    $rule += '
        ],
        "id": "Notification_Admin_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
    return $rule
}

function set-Notification_Activation_Assignee($Notification_Activation_Assignee) {
    $rule = '
         {
         "notificationType": "Email",
         "recipientType": "Requestor",
         "isDefaultRecipientsEnabled": '+ $Notification_Activation_Assignee.isDefaultRecipientEnabled.ToLower() + ',
         "notificationLevel": "'+ $Notification_Activation_Assignee.notificationLevel + '",
         "notificationRecipients": [
         '
    $Notification_Activation_Assignee.Recipients | % {
        $rule += '"' + $_ + '",'
    }
 
    $rule += '
         ],
         "id": "Notification_Requestor_EndUser_Assignment",
         "ruleType": "RoleManagementPolicyNotificationRule",
         "target": {
         "caller": "Admin",
         "operations": [
             "All"
         ],
         "level": "Eligibility",
         "targetObjects": null,
         "inheritableSettings": null,
         "enforcedSettings": null
         }
         }
         '
    return $rule
}

function Set-Notification_Activation_Approver ($Notification_Activation_Approver) {
    $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Approver.isDefaultRecipientEnabled.ToLower() + ',
        "notificationLevel": "'+ $Notification_Activation_Approver.notificationLevel + '",
        "notificationRecipients": [
        '
    <# 
            # Cant add backup recipient for this rule

            $Notification_Activation_Approver.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        #>
    $rule += '
        ],
        "id": "Notification_Approver_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
    return $rule
}

function Update-Policy ($policyID, $rules) {
    Log "Updating Policy $policyID"
    #write-verbose "rules: $rules"
    $body = '
        {
            "properties": {
            "scope": "'+ $scope + '",  
            "rules": [
        '+ $rules +
    '],
          "level": "Assignment"
            }
        }'
    write-verbose "`n>> PATCH body: $body"
    $restUri = "$ARMhost/$PolicyId/?api-version=2020-10-01"
    write-verbose "Patch URI : $restURI"
    $response = Invoke-RestMethod -Uri $restUri -Method PATCH -Headers $authHeader -Body $body -verbose:$false
}

function import-setting ($import) {
    log "Importing setting from $import"
    if (!(test-path $import)) {
        throw "Operation failed, file $import cannot be found"
    }
    $csv = Import-Csv $import

    $csv | % {
        $rules = @()
        $rules += Set-ActivationDuration $_.ActivationDuration
        $enablementRules = $_.EnablementRules.Split(',')
        $rules += Set-ActivationRequirement $enablementRules
        $approvers = @()
        $approvers += $_.approvers
        $rules += Set-ApprovalFromCSV $_.ApprovalRequired $Approvers
        $rules += Set-EligibilityAssignmentFromCSV $_.MaximumEligibleAssignmentDuration $_.AllowPermanentEligibleAssignment
        $rules += Set-ActiveAssignmentFromCSV $_.MaximumActiveAssignmentDuration $_.AllowPermanentActiveAssignment
            
        $Notification_EligibleAssignment_Alert = @{
            "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Alert_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Eligibility_Alert_notificationLevel;
            "Recipients"                = $_.Notification_Eligibility_Alert_Recipients.split(',')
        }
        $rules += Set-Notification_EligibleAssignment_Alert $Notification_EligibleAssignment_Alert

        $Notification_EligibleAssignment_Assignee = @{
            "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Assignee_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Eligibility_Assignee_notificationLevel;
            "Recipients"                = $_.Notification_Eligibility_Assignee_Recipients.split(',')
        }
        $rules += Set-Notification_EligibleAssignment_Assignee $Notification_EligibleAssignment_Assignee
            
        $Notification_EligibleAssignment_Approver = @{
            "isDefaultRecipientEnabled" = $_.Notification_Eligibility_Approvers_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Eligibility_Approvers_notificationLevel;
            "Recipients"                = $_.Notification_Eligibility_Approvers_Recipients.split(',')
        }
        $rules += Set-Notification_EligibleAssignment_Approver $Notification_EligibleAssignment_Approver

        $Notification_Active_Alert = @{
            "isDefaultRecipientEnabled" = $_.Notification_Active_Alert_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Active_Alert_notificationLevel;
            "Recipients"                = $_.Notification_Active_Alert_Recipients.split(',')
        }
        $rules += Set-Notification_ActiveAssignment_Alert $Notification_Active_Alert
            
        $Notification_Active_Assignee = @{
            "isDefaultRecipientEnabled" = $_.Notification_Active_Assignee_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Active_Assignee_notificationLevel;
            "Recipients"                = $_.Notification_Active_Assignee_Recipients.split(',')
        }
        $rules += Set-Notification_ActiveAssignment_Assignee $Notification_Active_Assignee
            
        $Notification_Active_Approvers = @{
            "isDefaultRecipientEnabled" = $_.Notification_Active_Approvers_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Active_Approvers_notificationLevel;
            "Recipients"                = $_.Notification_Active_Approvers_Recipients.split(',')
        }
        $rules += Set-Notification_ActiveAssignment_Approver $Notification_Active_Approvers

        $Notification_Activation_Alert = @{
            "isDefaultRecipientEnabled" = $_.Notification_Activation_Alert_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Activation_Alert_notificationLevel;
            "Recipients"                = $_.Notification_Activation_Alert_Recipients.split(',')
        }
        $rules += Set-Notification_Activation_Alert $Notification_Activation_Alert

        $Notification_Activation_Assignee = @{
            "isDefaultRecipientEnabled" = $_.Notification_Activation_Assignee_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Activation_Assignee_notificationLevel;
            "Recipients"                = $_.Notification_Activation_Assignee_Recipients.split(',')
        }
        $rules += Set-Notification_Activation_Assignee $Notification_Activation_Assignee

        $Notification_Activation_Approver = @{
            "isDefaultRecipientEnabled" = $_.Notification_Activation_Approver_isDefaultRecipientEnabled;
            "notificationLevel"         = $_.Notification_Activation_Approver_notificationLevel;
            "Recipients"                = $_.Notification_Activation_Approver_Recipients.split(',')
        }
        $rules += Set-Notification_Activation_Approver $Notification_Activation_Approver
            
        # patch the policy
        Update-Policy $_.policyID $($rules -join ',')
    }   
}
function Get-AllPolicies() {
    $restUri = "$ARMendpoint/roleDefinitions?`$select=roleName&api-version=2022-04-01"
    write-verbose "Getting All Policies at $restUri"
    $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
    $roles = $response | % { 
        $_.value.properties.roleName
    }
    return $roles
}
    
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
        import-setting $import
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